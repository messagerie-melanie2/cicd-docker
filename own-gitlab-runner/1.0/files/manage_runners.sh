#!/bin/bash

# # when a command fails, bash exits instead of continuing with the rest of the script.
# # This will make the script fail, when accessing an unset variable
# #This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.

# # Makes the script fail/exit when
# #   - A command fails
# #   - Accessing an unset variable
# #   - One command in a pipeline fails
set -o errexit
set -o nounset
set -o pipefail

# Default values
CI_SERVER_URL_DEFAULT='https://gitlab-forge.din.developpement-durable.gouv.fr/'
REGISTER_RUN_UNTAGGED_DEFAULT='true'
RUNNER_TAG_LIST_DEFAULT='docker,generated'
RUNNER_EXECUTOR_DEFAULT='docker'
DOCKER_IMAGE_DEFAULT='ruby:2.6'
RUNNER_NAME_DEFAULT='docker-generated-runner'
REGISTRATION_TOKEN_SECRET_DEFAULT='gitlab-runner-token-v1.0'
PROXY_TOKEN_SECRET_DEFAULT='proxy_tiger_backend_password-v1.0'
PROXY_USERNAME_SECRET_DEFAULT='proxy_tiger_backend_username-v1.0'
RUNNERS_COUNT_DEFAULT=2
REGISTRY_MIRROR_DEFAULT=""

# Global/Env variables
#
CI_SERVER_URL="${CI_SERVER_URL:-$CI_SERVER_URL_DEFAULT}"
REGISTER_RUN_UNTAGGED="${REGISTER_RUN_UNTAGGED:-$REGISTER_RUN_UNTAGGED_DEFAULT}"
RUNNER_TAG_LIST="${RUNNER_TAG_LIST:-$RUNNER_TAG_LIST_DEFAULT}"
RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-$RUNNER_EXECUTOR_DEFAULT}"
DOCKER_IMAGE="${DOCKER_IMAGE:-$DOCKER_IMAGE_DEFAULT}"
RUNNER_NAME="${RUNNER_NAME:-$RUNNER_NAME_DEFAULT}"
RUNNERS_COUNT="${RUNNERS_COUNT:-$RUNNERS_COUNT_DEFAULT}"
REGISTRY_MIRROR="${REGISTRY_MIRROR:-$REGISTRY_MIRROR_DEFAULT}"
# REGISTRATION_TOKEN="${REGISTRATION_TOKEN:-$REGISTRATION_TOKEN_DEFAULT}"
# REGISTRATION_TOKEN_SECRET="${REGISTRATION_TOKEN_SECRET:-$REGISTRATION_TOKEN_SECRET_DEFAULT}"

# Registration token (variable or secret)
REG_TOKEN_SECRET_NAME="${REGISTRATION_TOKEN_SECRET:-$REGISTRATION_TOKEN_SECRET_DEFAULT}"
REG_TOKEN_SECRET_PATH="/var/run/secrets/${REG_TOKEN_SECRET_NAME}"
# REG_TOKEN_SECRET_VALUE=$([ -f ${REG_TOKEN_SECRET_PATH} ] && cat ${REG_TOKEN_SECRET_PATH})
if [ -f "$REG_TOKEN_SECRET_PATH" ]; then
    REG_TOKEN_SECRET_VALUE=$(cat ${REG_TOKEN_SECRET_PATH})
else 
    REG_TOKEN_SECRET_VALUE='null'
fi
REG_TOKEN="${REGISTRATION_TOKEN:-$REG_TOKEN_SECRET_VALUE}"

# Proxy token (variable or secret)
PROXY_TOKEN_SECRET_NAME="${PROXY_TOKEN_SECRET:-$PROXY_TOKEN_SECRET_DEFAULT}"
PROXY_TOKEN_SECRET_PATH="/var/run/secrets/${PROXY_TOKEN_SECRET_NAME}"
PROXY_USERNAME_SECRET_NAME="${PROXY_USERNAME_SECRET:-$PROXY_USERNAME_SECRET_DEFAULT}"
PROXY_USERNAME_SECRET_PATH="/var/run/secrets/${PROXY_USERNAME_SECRET_NAME}"
# REG_TOKEN_SECRET_VALUE=$([ -f ${REG_TOKEN_SECRET_PATH} ] && cat ${REG_TOKEN_SECRET_PATH})
if [ -f "$PROXY_TOKEN_SECRET_PATH" ]; then
    PROXY_TOKEN_SECRET_VALUE=$(cat ${PROXY_TOKEN_SECRET_PATH})
    PROXY_USERNAME_SECRET_VALUE=$(cat ${PROXY_USERNAME_SECRET_PATH})
    PROXY_URL="http://${PROXY_USERNAME_SECRET_VALUE}:${PROXY_TOKEN_SECRET_VALUE}@${PROXY_URL}"
    printf "\nproxy ok\r"
else 
    PROXY_TOKEN_SECRET_VALUE='null'
    PROXY_USERNAME_SECRET_VALUE='null'
fi

# Proxy env variables
PROXY_URL_ARGS=''
if [ -n "${PROXY_URL-}" ]; then
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env proxy_url=${PROXY_URL}"
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env http_proxy=${PROXY_URL}"
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env https_proxy=${PROXY_URL}"
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env HTTP_PROXY=${PROXY_URL}"
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env HTTPS_PROXY=${PROXY_URL}"
    PROXY_URL_ARGS="${PROXY_URL_ARGS} --env NO_PROXY=${NO_PROXY}"
    if [[ "$REGISTRY_MIRROR" != "" ]]; then PROXY_URL_ARGS="${PROXY_URL_ARGS} --env REGISTRY_MIRROR=${REGISTRY_MIRROR}"; fi
fi

# Wait a bit
sleep 5s

printf "\n[gitlab-runner-container] Waiting ...\r" 
printf "\n[gitlab-runner-container] Starting ...\r"
# /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner &

# Unregister previous runners to avoid generating tons of runners
printf "\n[gitlab-runner-container] Removing previous runners ...\r"
gitlab-runner unregister --all-runners

# Register runners
printf "\n[gitlab-runner-container] Registering new runners ...\r"
for i in $(seq 1 ${RUNNERS_COUNT})
do
    printf "\n[gitlab-runner-container] Registering a new runner :";
    printf "\n\n\r"

    gitlab-runner register --non-interactive \
        --url ${CI_SERVER_URL} \
        --registration-token ${REG_TOKEN} \
        --executor ${RUNNER_EXECUTOR} --docker-image ${DOCKER_IMAGE} \
        --tag-list ${RUNNER_TAG_LIST} --run-untagged=${REGISTER_RUN_UNTAGGED} \
        --description ${RUNNER_NAME} ${PROXY_URL_ARGS}
done

set +o errexit
set +o nounset
set +o pipefail

printf "\n[gitlab-runner-container] Done !\r"
cat >/dev/null

# --- EOF ---