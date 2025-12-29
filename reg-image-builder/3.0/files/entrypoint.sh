#!/bin/bash

# when a command fails, bash exits instead of continuing with the rest of the script.
# This will make the script fail, when accessing an unset variable
#This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.

# Makes the script fail/exit when
#   - A command fails
#   - Accessing an unset variable
#   - One command in a pipeline fails
set -o errexit
set -o nounset
set -o pipefail

# Global variables
readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink $(dirname $0))
readonly ARGS="$@"

# Global variables from ENV
#
readonly CI_REGISTRY_USER=${CI_REGISTRY_USER}
readonly CI_REGISTRY_PASSWORD=${CI_REGISTRY_PASSWORD}
readonly CI_REGISTRY=${CI_REGISTRY}
#
readonly DOCKER_FILE_DIGEST=${DOCKER_FILE_DIGEST}
readonly DOCKER_PROXY_BUILD_ARGS=${DOCKER_PROXY_BUILD_ARGS}
readonly DOCKER_BUILD_ARGS=${DOCKER_BUILD_ARGS}
#
readonly TAG=${TAG}
readonly ALLOWED_PUSH=${ALLOWED_PUSH}
readonly BUILD_PWD=${BUILD_PWD}
readonly BUILD_PATH="${BUILD_PWD}/${BUILD_PATH}"
#
readonly DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN}
readonly DOCKERHUB_USER=${DOCKERHUB_USER}
#

# Functions

###
#  
#
# @see https://semaphoreci.com/blog/container-diff-tutorial
###
function compare_images()
{
    local reference_image=$1
    local compared_image=$2
    local comparison_types=$3
    #
    local comparison_types_args=""
    local comparison_res_file="container-diff-result.json"
    local compared_image_tarball="new-"
    #
    compared_image_tarball+=$reference_image

    for type in $comparison_types;
        do
            # container-diff diff $reference_image $compared_image --type=$type --json > container-diff-$type.json;
            comparison_types_args="${comparison_types_args} --type=$type";
    done;

    echo -e "\r\n[container-diff] Comparing images with container-diff...
        \r -- Source : $reference_image
        \r -- Target : $compared_image
        \r -- Comparison types : $comparison_types
        \r -- Output file : $comparison_res_file"
    
    echo -e "\r\n[crane] Authenticating to registry gitlab"
    crane auth login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

    echo -e "\r\n[crane] Authenticating to registry docker"
    crane auth login -u $DOCKERHUB_USER -p $DOCKERHUB_TOKEN registry.hub.docker.com

    # Pulling the image in the registry to prevent container-diff to fail
    echo -e "\r\n[crane] Pulling the image ${compared_image}..."

    if crane pull ${compared_image} ${compared_image_tarball}
    then
        # Do the comparison using container-diff
        container-diff diff $reference_image $compared_image_tarball $comparison_types_args --json > $comparison_res_file;
         # Store changes 
        changes_history=$(jq '.[] | select(.DiffType=="History") |  .Diff.Adds + .Diff.Dels | length' ${comparison_res_file})
        changes_file=$(jq '.[] | select(.DiffType=="File") |  .Diff.Adds + .Diff.Dels | length' ${comparison_res_file})
        changes_apt=$(jq '.[] | select(.DiffType=="Apt")  | .Diff.Packages1 + .Diff.Packages2 | length' ${comparison_res_file})

        # When sizes are equal jq returns a string "null"
        size1=$(jq '.[] | select(.DiffType=="Size") | .Diff[0].Size1 ' ${comparison_res_file})
        size2=$(jq '.[] | select(.DiffType=="Size") | .Diff[0].Size2 ' ${comparison_res_file})

        if [ "$size1" = "null" ]
        then
        size_ratio=0
        else
        size_ratio=$(jq '.[] | select(.DiffType=="Size") | 100 * .Diff[0].Size2 / .Diff[0].Size1 - 100 | floor' ${comparison_res_file})
        fi

        echo -e "\r\n[container-diff] Images comparison results :
            \r -- changes_history : $changes_history
            \r -- changes_file : $changes_file
            \r -- changes_apt : $changes_apt
            \r -- sizes : $size1 vs $size2
            \r -- size_ratio : $size_ratio"

        # # Compare container and stop pipeline when changes exceed control parameters
        # # Parameters expected:
        # #   $ALLOWED_APT_CHANGES - max number of allowed APT packages changed
        # #   $ALLOWED_HISTORY_CHANGES - max number of Dockerfile commands changed
        # #   $ALLOWED_NPM_CHANGES - max number of NPM packages changed
        # #   $MAX_GROWTH_RATIO - percentual growth size allowed (0 is no growth, 100 is double size)

        # # Evaluate changes against control parameters
        # if [ $changes_apt -gt $ALLOWED_APT_CHANGES ] \
        # || [ $changes_history -gt $ALLOWED_HISTORY_CHANGES ] \
        # || [ $changes_npm -gt $ALLOWED_NPM_CHANGES ] \
        # || [ $size_ratio -gt $MAX_GROWTH_RATIO ]
        # then
        # exit 1
        # else
        # echo OK
        # fi

        # If Dockerfile changed, or apt packages changed, rebuild the image
        ALLOWED_APT_CHANGES=0
        ALLOWED_HISTORY_CHANGES=0
        ALLOWED_FILE_CHANGES=0


        if [ $changes_history -gt $ALLOWED_HISTORY_CHANGES ] \
        || [ $changes_apt -gt $ALLOWED_APT_CHANGES ] \
        || [ $changes_file -gt $ALLOWED_FILE_CHANGES ]
        then
            export PUSH=1
            echo -e "\r\n[container-diff] Changes found, this new image needs to be pushed to the registry !"
        else
            export PUSH=0
            echo -e "\r\n[container-diff] No changes found, do not push that image, it already exist on the registry !"
        fi
    else
        echo -e "\r\n[crane] ${compared_image} does not exist..."
        export PUSH=1
    fi
}

###
#
#
###
function build_image()
{
    # Optional function argument to add more arguments to the build command
    local output=${1:-""}

    # Build the docker image with the given arguments
    echo -e "\r\n[entrypoint.sh] My job is to build docker image ${TAG}..."

    buildctl-daemonless.sh build \
        --frontend dockerfile.v0 \
        --local context="${BUILD_PATH}" --local dockerfile="${BUILD_PATH}" $DOCKER_PROXY_BUILD_ARGS $DOCKER_BUILD_ARGS \
        --output $output

}

# Main script instructions
main()
{
    # Display exported variables
    # TODO : only if ci-debug
    # echo -e "$(export -p | grep PROXY)"
    # echo -e "$(export -p | grep GITLAB)"
    # echo -e "$(export -p | grep CI)"
    # echo -e "$(export -p | grep RULE)"
    # echo -e '\r\n>> Done 😃 <<\r\n'

    # Check that Kaniko configuration exists and contains a key for our registry
    if [[ "$(cat ~/.docker/config.json)" == *"$CI_REGISTRY"* ]];
    then
        if [[ "${CHECK_BEFORE_PUSH:-}" ]];
        then
            # Define some useful variables
            local local_image_oci=${TAG##*/}_oci.tar
            local output="type=oci,name=$TAG,dest=$local_image_oci"
            
            # Build image without pushing it
            build_image $output

            local local_image=${TAG##*/}.tar
            skopeo copy oci-archive:$local_image_oci docker-archive:$local_image:$TAG

            # Compare built image with existing image
            echo -e "\r\n[entrypoint.sh] Comparing built image with existing ${TAG}..."

            # Compare image to know if there's real changes to push
            compare_images $local_image $TAG "history apt size file node"

            if [[ "${PUSH}" == 1 ]]
            then
                echo -e "\r\n[crane] Authenticating to registry"
                crane auth login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

                echo -e "\r\n[crane] Pushing the image ${TAG}..."
                crane push ${local_image} ${TAG}
            else
                rm -f $DOCKER_FILE_DIGEST
                echo -e "\r\n[entrypoint.sh] Image wasn't pushed, exiting script."
            fi

        else
            # Display an informational message
            echo -e "\r\n[entrypoint.sh] No 'CHECK_BEFORE_PUSH' parameter found, the image will be built and pushed immediately."

            # Build image and push it immediately
            local output="type=image,name=$TAG,push=$ALLOWED_PUSH"
            build_image $output
        fi
    else
        # Display an informational message
        echo -e "\r\n[entrypoint.sh] Kaniko/Docker auth configuration doesn't reference our registry, aborting."

        # Exit with error
        exit 1
    fi
}

# Run the script
main $ARGS