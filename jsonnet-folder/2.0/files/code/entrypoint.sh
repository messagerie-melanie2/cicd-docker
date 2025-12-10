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
readonly CI_PROJECT_NAME=${CI_PROJECT_NAME}
readonly CI_PIPELINE_FOLDER_PATH=${CI_PIPELINE_FOLDER_PATH:"cicd-docker/pipelines"}
readonly CI_PIPELINE_YAML_FOLDER_PATH=${CI_PIPELINE_FOLDER_PATH:"cicd-docker/pipelines_yaml"}
readonly CI_PROJECT_NAMESPACE=${CI_PROJECT_NAMESPACE}
readonly RUNNER_TAGS=${RUNNER_TAGS}


# Main script instructions
main()
{

    # Définir le chemin du dossier pipelines
    pipelines_dir="/builds/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/$CI_PIPELINE_FOLDER_PATH"

    # Créer un dossier de sortie pour les fichiers YAML générés
    output_dir="/builds/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/$CI_PIPELINE_YAML_FOLDER_PATH"
    mkdir -p "$output_dir"

    ls -d $PWD/*

    # Vérifier si le dossier existe
    if [ ! -d "$pipelines_dir" ]; then
        echo "Le dossier '$pipelines_dir' n'existe pas."
        exit 1
    fi

    # Récupérer tous les fichiers .jsonnet dans le dossier pipelines
    jsonnet_files=$(find "$pipelines_dir" -type f -name "*.jsonnet")

    # Vérifier s'il y a des fichiers .jsonnet
    if [ -z "$jsonnet_files" ]; then
        echo "Aucun fichier .jsonnet trouvé dans le dossier '$pipelines_dir'."
        exit 0
    fi

    # Boucle à travers tous les fichiers .jsonnet et exécuter la commande jsonnet 
    for file in $jsonnet_files; do
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"
        output_file="$output_dir/$filename.yaml"

        echo "Traitement du fichier $file ..."
        jsonnet -o "$output_file" "$file" --ext-str RUNNER_TAGS="$RUNNER_TAGS"
        echo "Fichier YAML créé : $output_file"
    done

    echo "Tous les fichiers .jsonnet ont été traités avec succès."

    echo "Convertion du json en yaml."
}

# Run the script
main $ARGS