# Get image registry provided by the build command
# i.e. 'docker build --build-arg registry={...} .'
ARG registry
ARG registry_default=registry.gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/cicd/cicd-docker

# Version of the parent Docker image (FROM...)
# Used to build full version string : {parent_version}_{image_version}
#
# parent_version - version provided by the build command ('docker build --build-arg parent_version={...} .')
# parent_version_default - fallback value if no parent_version was found, also used by the python script (for CI/CD)
# parent_version_replace_with - string that will replace the parent_version in the tag of the docker image

ARG parent_version
ARG parent_version_default=rootless
ARG parent_version_replace_with=3.0

# Version of the Docker image built with this Dockerfile 
# Used to build full version string : {parent_version}_{image_version}
# 
# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_default - fallback value if no image_version was found, also used by the python script (for CI/CD)
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image
#
ARG image_version
ARG image_version_default=3.0
ARG image_version_replace=false

############################################################################# 
# Use the version provided by the build command
# or fall back to the default one
FROM moby/buildkit:${parent_version:-${parent_version_default}}
#
# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="build" \
    maintainers="TOLIMAT Hamza"

# Copy binaries and files (including /etc/bash/.bashrc)
#
USER root

COPY requirements_alp .
RUN apk update && \
    apk upgrade && \
    apk add $(sed -e '/^#/d' requirements_alp)

# Install container-diff
RUN curl -LO https://storage.googleapis.com/container-diff/v0.17.0/container-diff-linux-amd64 && \
    install container-diff-linux-amd64 /usr/local/bin/container-diff

# Install crane
RUN curl -L https://github.com/google/go-containerregistry/releases/download/v0.17.0/go-containerregistry_Linux_x86_64.tar.gz > go-containerregistry.tar.gz && \
    tar -xf go-containerregistry.tar.gz  && \
    install crane /usr/local/bin/crane

# Install jq
RUN curl -LO https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    install jq-linux64 /usr/local/bin/jq

#
############################################################
############################################################
# Builder entrypoint and command(s)
#
USER 1000

COPY --chmod=755 files/entrypoint.sh /builder/entrypoint.sh
#
# Run the script on container startup
CMD ["exec /builder/entrypoint.sh"]
#
# Execute the given command (above, or override) using bash 
ENTRYPOINT ["/bin/bash", "-c"]