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
readonly CI_JOB_TOKEN=${CI_JOB_TOKEN}
readonly GITLAB_DOMAIN=${GITLAB_DOMAIN}


# Main script instructions
main()
{
    echo https://gitlab-ci-token:$CI_JOB_TOKEN@${GITLAB_DOMAIN} > /root/.git-credentials
    git config --global credential.helper store

    # Récupère la liste des sous-dossiers (dépôts Git)
    subdirectories=$(find $1 -maxdepth 1 -type d)
    # Parcours chaque sous-dossier
    for dir in $subdirectories; do
    if [ -d "$dir/.git" ]; then
        sed -i "s|url = https://g.*@${GITLAB_DOMAIN}|url = https://${GITLAB_DOMAIN}|g" "$dir/.git/config"
        # Vérifie si le sous-dossier est un dépôt Git
        echo "Synchronisation du dépôt Git dans le dossier : $dir"
        (cd "$dir" && git pull)
        echo "Synchronisation terminée pour le dépôt dans le dossier : $dir"
        echo
    fi
    done
}

# Run the script
main $ARGS