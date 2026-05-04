# Get image registry provided by the build command
# i.e. 'docker build --build-arg registry={...} .'
ARG registry

# Version of the parent Docker image (FROM...)
# Used to build full version string : {parent_version}_{image_version}
#
# parent_version - version provided by the build command ('docker build --build-arg parent_version={...} .')
# parent_version_default - fallback value if no parent_version was found, also used by the python script (for CI/CD)
# parent_version_replace_with - string that will replace the parent_version in the tag of the docker image

ARG parent_version
ARG parent_version_default=v15.10.0
#ARG parent_version_replace_with=1.0

# Version of the Docker image built with this Dockerfile
# Used to build full version string : {parent_version}_{image_version}
#
# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_default - fallback value if no image_version was found, also used by the python script (for CI/CD)
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image
#
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

# Use Kaniko source image
# FROM gcr.io/kaniko-project/executor:v1.9.1-debug as kaniko
FROM gitlab/gitlab-runner:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="runner" \
    maintainers="COMBES Julien, TOLIMAT Hamza"

# Install required debian packages
COPY requirements_deb .
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y $(sed -e '/^#/d' requirements_deb) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm requirements_deb

COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/dockerentrypoint.py /usr/local/bin/
COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/yamlentrypoint.py /usr/local/bin/
COPY files/yaml.d /usr/local/etc/yaml.d

# Copy base config file
COPY files/config/config.toml.template /etc/gitlab-runner/config.toml.template
COPY files/config/config.toml /etc/gitlab-runner/config.toml

# Copy entrypoint script
COPY files/entrypoint/entrypoint_override.sh /entrypoint_override
COPY files/entrypoint/manage_runners.py /usr/local/etc/template.d/gitlabrunner/manage_runners.py

# Execute the new entrypoint
ENTRYPOINT ["/usr/bin/dumb-init","-vvv","/entrypoint_override"]