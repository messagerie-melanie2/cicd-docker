#!/bin/bash

# when a command fails, bash exits instead of continuing with the rest of the script.
# This will make the script fail, when accessing an unset variable
#This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.

# Makes the script fail/exit when
#   - A command fails
#   - Accessing an unset variable
#   - One command in a pipeline fails
# set -o errexit
# set -o nounset
# set -o pipefail

# # Global variables
readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink $(dirname $0))
readonly ARGS="$@"

# Global variables from ENV
#
readonly ENTRYPOINT_NAME=${ENTRYPOINT_NAME}


# Main script instructions
main()
{
    GITLAB_TOKEN=$(cat /run/secrets/unit_test_gitlab_token-v1.0)
    
    echo https://test-unit:$GITLAB_TOKEN@gitlab-forge.din.developpement-durable.gouv.fr > /root/.git-credentials
    git config --global credential.helper store

    cd /usr/local/entrypoint/cicd-unit-test
    dir=$(pwd)

    sed -i 's/url = https:\/\/g.*@gitlab-forge\.din\.developpement-durable\.gouv\.fr/url = https:\/\/gitlab-forge\.din\.developpement-durable\.gouv\.fr/g' $dir/.git/config
    echo "Synchronisation du dépôt Git dans le dossier : $dir"
    (cd "$dir" && git pull)
    echo "Synchronisation terminée pour le dépôt dans le dossier : $dir"

    cp "$dir/yaml.d/$ENTRYPOINT_NAME.yml" "/usr/local/etc/yaml.d/$ENTRYPOINT_NAME.yml"
    echo "Fichier $dir/yaml.d/$ENTRYPOINT_NAME.yml copié en /usr/local/etc/yaml.d/$ENTRYPOINT_NAME.yml"

    cp "$dir/script/$ENTRYPOINT_NAME.py" "/usr/local/etc/template.d/$ENTRYPOINT_NAME.py.template"
    echo "Fichier $dir/script/$ENTRYPOINT_NAME.py copié en /usr/local/etc/template.d/$ENTRYPOINT_NAME.py.template"

    /usr/local/bin/yamlentrypoint.py --yamldir /usr/local/etc/yaml.d
    
    echo
}

# Run the script
main $ARGS