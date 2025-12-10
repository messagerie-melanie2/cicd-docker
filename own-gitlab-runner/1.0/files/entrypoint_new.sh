#!/bin/bash

R='\033[0;31m'
G='\033[0;32m'
B='\033[0;34m'
P='\033[0;35m'
Y='\033[0;33m'
W='\033[0;37m'

logline()
{
    printf "\r\n -- $1 -- \r\n"
}

unregister()
{
    logline "[${Y}UNREGISTER${W}] ${G}Start${W}"

    gitlab-runner unregister --all-runners

    logline "[${Y}UNREGISTER${W}] ${R}End${W}"
}

init()
{
    logline "[${P}INIT${W}] ${G}Start${W}"

    sleep 5s
    # -
    logline "[gitlab-runner-container] Registering a new runner :";

    logline "[${P}INIT${W}] ${R}End${W}"
}

run()
{
    logline "[${B}RUN${W}] ${G}Start${W}"

    # Call image entrypoint "as usual"
    #
    # @see https://hub.docker.com/r/gitlab/gitlab-runner/dockerfile
    # @see https://gitlab.com/gitlab-org/gitlab-runner/-/blob/main/dockerfiles/runner/ubuntu/entrypoint
    # @see https://github.com/Yelp/dumb-init#session-behavior
    /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner

    logline "[${B}RUN${W}] ${R}End${W}"
}

# put a function in the background
init &

# do something
run --user=gitlab-runner --working-directory=/home/gitlab-runner

# 
unregister