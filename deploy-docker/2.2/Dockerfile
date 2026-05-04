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
ARG parent_version_default=2.6
# ARG parent_version_replace_with= 

# Version of the Docker image built with this Dockerfile
# Used to build full version string : {parent_version}_{image_version}

# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image

# ARG image_version
ARG image_version_replace=true

ARG registry_git_image_path
ARG git_image_name
ARG git_image_tag
# Docker Multistage : récupération de l'entrypoint
###############################################################################
FROM ${registry}${registry_git_image_path}/${git_image_name}:${git_image_tag} AS pullentrypoint
ARG build_branch
ARG ci_job_token
ARG docker_tools_path
ARG gitlab_domain
RUN /usr/local/bin/clonegit.py "https://gitlab-ci-token:${ci_job_token}@${gitlab_domain}${docker_tools_path}.git" ${build_branch}


# Docker Multistage : build docker
#############################################################################
# Use the version provided by the build command
# or fall back to the default one
FROM ruby:${parent_version:-${parent_version_default}}

ARG cicd_gmcd_token
ARG deploy_group_id
ARG gitlab_domain
ARG ci_job_token

ENV CICD_GMCD_TOKEN=${cicd_gmcd_token}
ENV CI_JOB_TOKEN=${ci_job_token}
ENV GROUP_ID=${deploy_group_id}
ENV GITLAB_DOMAIN=${gitlab_domain}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="deploy" \
    maintainers="COMBES Julien, TOLIMAT Hamza"

# Install required debian packages
COPY requirements_deb .
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y $(sed -e '/^#/d' requirements_deb) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm requirements_deb

# Install required python packages
COPY requirements_pip .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements_pip

COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/dockerentrypoint.py /usr/local/bin/
COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/yamlentrypoint.py /usr/local/bin/
COPY files/yaml.d /usr/local/etc/yaml.d

RUN mkdir -p /usr/local/clusters
COPY files/entrypoint /usr/local/clusters
COPY files/script /usr/local/clusters

# Configure image settings
ENV TZ Europe/Paris
WORKDIR /usr/local/clusters

USER root

RUN chmod +x /usr/local/clusters/git_clone_clusters.py

RUN /usr/local/clusters/git_clone_clusters.py

ENV CICD_GMCD_TOKEN=""

CMD ["/usr/local/bin/yamlentrypoint.py", "--yamldir", "/usr/local/etc/yaml.d"]

#######
