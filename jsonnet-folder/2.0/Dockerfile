# Get image registry provided by the build command
# i.e. 'docker build --build-arg registry={...} .'
ARG registry

# Version of the parent Docker image (FROM...) 
# Used to build full version string : {parent_version}_{image_version}
#
# parent_version - version provided by the build command ('docker build --build-arg parent_version={...} .')
# parent_version_default - fallback value if no parent_version was found, also used by the python script (for CI/CD)
# parent_version_replace_with - string that will replace the parent_version in the tag of the docker image
#
ARG parent_version
ARG parent_version_default=0.17.0
# ARG parent_version_replace_with=

# Version of the Docker image built with this Dockerfile 
# Used to build full version string : {parent_version}_{image_version}

# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image

# ARG image_version
ARG image_version_replace=true

FROM debian:${parent_version:-${parent_version_default}} AS compil

# Install required debian packages

COPY requirements_compil .
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y $(sed -e '/^#/d' requirements_compil) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm requirements_compil

RUN git clone https://github.com/google/jsonnet.git

WORKDIR /jsonnet

RUN make

#############################################################################
# Use the version provided by the build command
# or fall back to the default one
FROM debian:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="jsonnet" \
    maintainers="COMBES Julien, TOLIMAT Hamza"

COPY files/code /

# Configure image settings
ENV TZ Europe/Paris

USER root

COPY --from=compil /jsonnet/jsonnet /usr/bin/jsonnet

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

########
