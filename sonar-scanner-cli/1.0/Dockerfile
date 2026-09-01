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
# ARG parent_version_default=bookworm-slim_1.0
# ARG parent_version_replace_with=

# Version of the Docker image built with this Dockerfile
# Used to build full version string : {parent_version}_{image_version}
#
# image_version - version provided by the build command ('docker build --build-arg image_version={...} .')
# image_version_replace - if true, image_version will replace the image_version contained in parent_version in the tag of the docker image
#
ARG image_version
ARG image_version_replace=true

# Docker Multistage : construction du docker
###############################################################################

# Use the version provided by the build command
# or fall back to the default one
FROM sonarsource/sonar-scanner-cli:${parent_version:-${parent_version_default}}

# Add image information
LABEL \
    category="sonar" \
    scope="scanner" \
    target="cli" \
    maintainers="Tolimat Hamza"

#
