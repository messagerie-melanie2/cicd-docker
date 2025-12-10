# Get image registry provided by the build command
# i.e. 'docker build --build-arg registry={...} .'
ARG registry
ARG registry_default=registry.gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/cicd-docker

# Version of the parent Docker image (FROM...)
# Used to build full version string : {parent_version}_{image_version}
#
# parent_version - version provided by the build command ('docker build --build-arg parent_version={...} .')
# parent_version_default - fallback value if no parent_version was found, also used by the python script (for CI/CD)
# parent_version_replace_with - string that will replace the parent_version in the tag of the docker image

ARG parent_version
ARG parent_version_default=v15.10.0
ARG parent_version_replace_with=1.0

# Version of the Docker image built with this Dockerfile 
# Used to build full version string : {parent_version}_{image_version}
#
# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_default - fallback value if no image_version was found, also used by the python script (for CI/CD)
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image
#
ARG image_version
ARG image_version_default=1.0
ARG image_version_replace=false

# Use Kaniko source image
# FROM gcr.io/kaniko-project/executor:v1.9.1-debug as kaniko
FROM gitlab/gitlab-runner:${parent_version:-${parent_version_default}}

# Add image information
# LABEL \
#     category="tools" \
#     scope="cicd" \
#     target="..." \
#     maintainers="GARCIA Tom-Brian"

# Copy base config file
COPY files/config.toml /etc/gitlab-runner/config.toml

# Copy entrypoint script
COPY files/entrypoint_override.sh /entrypoint_override
COPY files/manage_runners.sh /manage_runners
# --chown=root:root
# RUN chmod 755 $ENTRYPOINT

# Execute the new entrypoint
# ENTRYPOINT ["/entrypoint_override"]
ENTRYPOINT ["/usr/bin/dumb-init","-vvv","/entrypoint_override"]