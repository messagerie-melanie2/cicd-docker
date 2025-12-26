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
ARG parent_version_default=v1.19.2-debug
ARG parent_version_replace_with=2.0

# Version of the Docker image built with this Dockerfile
# Used to build full version string : {parent_version}_{image_version}
# 
# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_default - fallback value if no image_version was found, also used by the python script (for CI/CD)
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image
#
ARG image_version
ARG image_version_default=2.0
ARG image_version_replace=false

#################
# STAGE : TOOLS
#################

# Use the version provided by the build command
# or fall back to the default one
FROM alpine:3.17 as tools

COPY requirements_alp .
RUN apk update && \
    apk upgrade && \
    apk add $(sed -e '/^#/d' requirements_alp)
    # apt-get clean && \
    # rm -rf /var/lib/apt/lists/*

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
    
# ENTRYPOINT /bin/bash

################# 
# TARGET IMAGE
#################

# Use Kaniko source image
# FROM gcr.io/kaniko-project/executor:v1.9.1-debug as kaniko
FROM ${registry:-${registry_default}}/kaniko-executor:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="build" \
    maintainers="GARCIA Tom-Brian"

# Copy binaries and files (including /etc/bash/.bashrc)
#
# bash
COPY --from=tools /bin/bash /bin/bash
COPY --from=tools /etc/bash /etc/bash
#
# jq
# COPY --from=tools /usr/bin/jq /bin/jq

# Copy required libs related to these binaries
#
# shared
COPY --from=tools /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
# bash (`ldd /bin/bash`)
COPY --from=tools /usr/lib/libreadline.so.8 /usr/lib/libreadline.so.8
COPY --from=tools /usr/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
# # jq (`ldd /usr/bin/jq`)
# COPY --from=tools /usr/lib/libjq.so.1 /usr/lib/libjq.so.1
# COPY --from=tools /usr/lib/libjq.so.1.0.4 /usr/lib/libjq.so.1.0.4
# COPY --from=tools /usr/lib/libonig.so.5 /usr/lib/libonig.so.5
############################################################
############################################################
# 'Kaniko Builder' paths definition
#
# Base directory (Kaniko Builder Path)
ENV KBP=/kaniko/builder
#
# Binaries directory (Kaniko Builder Binary)
ENV KBB=$KBP/bin
#
# Entrypoint directory (Kaniko Builder Entrypoint)
ENV KBE=$KBP/entrypoint.sh
############################################################
############################################################
# 'Kaniko Builder' required tools
#
# Create directories
RUN mkdir -p $KBB
#
# Copy bash in that directory
COPY --from=tools /usr/local/bin/* $KBB/
#
# Copy other tools in that directory (container-diff, crane, jq, bash)
COPY --from=tools /usr/local/bin/* $KBB/
#
# Update PATH to find tools
ENV PATH="$PATH:/bin:$KBB"
############################################################
############################################################
# 'Kaniko Builder' entrypoint and command(s)
#
# Copy entrypoint script
COPY --chown=0:0 files/entrypoint.sh $KBE
RUN chmod 755 $KBE
#
# Run the script on container startup
CMD ["exec $KBE"]
#
# Execute the given command (above, or override) using bash
ENTRYPOINT ["/bin/bash", "-c"]
############################################################
############################################################

# RUN mv /bin/bash /kaniko/bash && ln -sf /kaniko/bash /bin/sh  # symlink is necessary!
# SHELL ["/kaniko/bash","-c"]