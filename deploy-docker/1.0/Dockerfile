# Get image registry provided by the build command
# i.e. 'docker build --build-arg registry={...} .'
ARG registry
ARG registry_default=registry.gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/mel-docker

# Version of the parent Docker image (FROM...)
# Used to build full version string : {parent_version}_{image_version}
#
# parent_version - version provided by the build command ('docker build --build-arg parent_version={...} .')
# parent_version_default - fallback value if no parent_version was found, also used by the python script (for CI/CD)
# parent_version_replace_with - string that will replace the parent_version in the tag of the docker image
#
ARG parent_version
ARG parent_version_default=2.6
# ARG parent_version_replace_with= 

# Version of the Docker image built with this Dockerfile
# Used to build full version string : {parent_version}_{image_version}

# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image

# ARG image_version
ARG image_version_replace=true

# Docker Multistage : récupération des sources pam mce
###############################################################################
FROM ${registry:-${registry_default}}/git-mce-generic:bookworm-slim_1.0 AS pullentrypoint
ARG build_branch
ARG ci_job_token
RUN /usr/local/bin/clonegit.py "https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/docker-tools.git" ${build_branch}


# Docker Multistage : build docker
############################################################################# 
# Use the version provided by the build command
# or fall back to the default one
FROM ruby:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="deploy" \
    maintainers="COMBES Julien, TOLIMAT Hamza"


# Install required debian packages
COPY requirements_deb .
RUN apt-get update && \
    apt-get install -y $(sed -e '/^#/d' requirements_deb) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm requirements_deb

COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/dockerentrypoint.py /usr/local/bin/
COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/yamlentrypoint.py /usr/local/bin/
COPY files/yaml.d /usr/local/etc/yaml.d

RUN mkdir -p /usr/local/swarm_clusters
COPY files/code /usr/local/swarm_clusters

# Configure image settings
ENV TZ Europe/Paris
WORKDIR /usr/local/swarm_clusters

USER root

RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-admin.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-admin-tools.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-ambackend.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-backend.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-client.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-master.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-relternet.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-reltranet.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-web.git 
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/cluster-test.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/smtp-client.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/smtp-relternet.git
RUN git clone https://gitlab-ci-token:${ci_job_token}@gitlab-forge.din.developpement-durable.gouv.fr/snum/detn/gmcd/conf-cluster-swarm/smtp-reltranet.git

CMD ["/usr/local/bin/yamlentrypoint.py", "--yamldir", "/usr/local/etc/yaml.d"]

######## 
