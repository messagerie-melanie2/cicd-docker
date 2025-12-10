#!/bin/sh

# If
if [ "${DEBUG+set}" = set ] && [ "$DEBUG" = true ]; then
  DEBUG_TRIGGER="--debug"
fi

# # launch a process in the background
# my-web-server & 
# # launch another process in the foreground
# my-other-server 

# Call custom script to manage runners (unregister, register)
/manage_runners &

# Call image entrypoint "as usual"
#
# @see https://hub.docker.com/r/gitlab/gitlab-runner/dockerfile
# @see https://gitlab.com/gitlab-org/gitlab-runner/-/blob/main/dockerfiles/runner/ubuntu/entrypoint
# @see https://github.com/Yelp/dumb-init#session-behavior
/entrypoint ${DEBUG_TRIGGER:-} run --user=gitlab-runner --working-directory=/home/gitlab-runner

# --- EOF ---