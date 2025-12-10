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
readonly KANIKO_PROXY_BUILD_ARGS=${KANIKO_PROXY_BUILD_ARGS}
readonly DOCKER_BUILD_ARGS=${DOCKER_BUILD_ARGS}
#
readonly TAG=${TAG}
readonly BUILD_PWD=${BUILD_PWD}
readonly BUILD_PATH="${BUILD_PWD}/${BUILD_PATH}"

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
    
    # Copy registry credentials from Kaniko
    mkdir -p /root/.docker
    ln -sf /kaniko/.docker/config.json /root/.docker/config.json
    
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
    
    # Do the comparison using container-diff
    container-diff diff $reference_image $compared_image $comparison_types_args --json > $comparison_res_file;

    # Store changes 
    changes_history=$(jq '.[] | select(.DiffType=="History") |  .Diff.Adds + .Diff.Dels | length' ${comparison_res_file})
    changes_file=$(jq '.[] | select(.DiffType=="File") |  .Diff.Adds + .Diff.Dels | length' ${comparison_res_file})
    changes_apt=$(jq '.[] | select(.DiffType=="Apt")  | .Diff.Packages1 + .Diff.Packages2 | length' ${comparison_res_file})
    changes_npm=$(jq '.[] | select(.DiffType=="Node") | .Diff.Packages1 + .Diff.Packages2 | length' ${comparison_res_file})

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
        \r -- changes_npm : $changes_npm
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

    if [ $changes_history -gt $ALLOWED_HISTORY_CHANGES ] \
    || [ $changes_apt -gt $ALLOWED_APT_CHANGES ]
    then
        export PUSH=1
        echo -e "\r\n[container-diff] Changes found, this new image needs to be pushed to the registry !"
    else
        export PUSH=0
        echo -e "\r\n[container-diff] No changes found, do not push that image, it already exist on the registry !"
    fi
}

###
#
#
###
function build_image()
{
    # Optional function argument to add more arguments to the kaniko build command
    local kaniko_args=${1:-""}

    # Build the docker image with the given arguments
    echo -e "\r\n[entrypoint.sh] My job is to build docker image ${TAG}..."

    # Execute Kaniko command, using build args and previously built/given variables
    # --------------------------------------------------------------------------------------------------------------------------------
    # || Parameter                  || Description                          || Reference
    # || --whitelist-var-run=false  || Fixes an error related to /var/run   || https://github.com/GoogleContainerTools/kaniko/issues/506
    # || --cleanup --cache=false    || Fixes an error related to /bin/bash  || https://github.com/GoogleContainerTools/kaniko/issues/1335
    executor --context ${BUILD_PATH} \
      --dockerfile "${BUILD_PATH}/Dockerfile" $KANIKO_PROXY_BUILD_ARGS $DOCKER_BUILD_ARGS \
      --destination $TAG --whitelist-var-run=false --cleanup --cache=false $kaniko_args

    echo "
    executor --context ${BUILD_PATH} \
      --dockerfile \"${BUILD_PATH}/Dockerfile\" $KANIKO_PROXY_BUILD_ARGS $DOCKER_BUILD_ARGS \
      --destination $TAG --whitelist-var-run=false --cleanup --cache=false $kaniko_args
    "

}

# Main script instructions
main()
{
    # Display exported variables
    # TODO : only if ci-debug
    echo -e "$(export -p | grep PROXY)"
    echo -e "$(export -p | grep GITLAB)"
    echo -e "$(export -p | grep CI)"
    echo -e "$(export -p | grep RULE)"
    echo -e '\r\n>> Done 😃 <<\r\n'

    # Check that Kaniko configuration exists and contains a key for our registry
    if [[ "$(cat /kaniko/.docker/config.json)" == *"$CI_REGISTRY"* ]];
    then
        # TODO check if remote image exist ???
        #

        if [[ "${CHECK_BEFORE_PUSH:-}" ]];
        then
            # Define some useful variables
            local local_image=${TAG##*/}.tar
            
            # Build image without pushing it
            build_image "--no-push --tar-path ${local_image}"

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
                echo -e "\r\n[entrypoint.sh] Image wasn't pushed, exiting script."
            fi

        else
            # Display an informational message
            echo -e "\r\n[entrypoint.sh] No 'CHECK_BEFORE_PUSH' parameter found, the image will be built and pushed immediately."

            # Build image and push it immediately
            build_image
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