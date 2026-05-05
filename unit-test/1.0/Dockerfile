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
ARG parent_version_default=3.9
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
FROM ${registry}/${registry_git_image_path}/${git_image_name}:${git_image_tag} AS pullentrypoint
ARG build_branch
ARG ci_job_token
ARG docker_tools_path
ARG gitlab_domain
RUN /usr/local/bin/clonegit.py "https://gitlab-ci-token:${ci_job_token}@${gitlab_domain}${docker_tools_path}.git" ${build_branch}

############################################################################# 
# Use the version provided by the build command
# or fall back to the default one
FROM python:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="tools" \
    scope="cicd" \
    target="jsonnet" \
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

RUN playwright install --with-deps chromium

COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/dockerentrypoint.py /usr/local/bin/
COPY --from=pullentrypoint /source/docker-tools/python-docker-entrypoint/yamlentrypoint.py /usr/local/bin/
COPY files/yaml.d /usr/local/etc/yaml.d
COPY files/entrypoint /usr/local/entrypoint
RUN mkdir /usr/local/etc/template.d

# Configure image settings
ENV TZ Europe/Paris

USER root
WORKDIR /usr/local/entrypoint

ARG gitlab_domain
ARG cicd_unit_test_path

RUN git clone https://gitlab-ci-token:${ci_job_token}@${gitlab_domain}${cicd_unit_test_path}.git

CMD ["sh", "/usr/local/entrypoint/launch_unit_test.sh"]
########
