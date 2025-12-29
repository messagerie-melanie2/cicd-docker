#!/bin/sh

# when a command fails, bash exits instead of continuing with the rest of the script.
# This will make the script fail, when accessing an unset variable
# This will ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.

# Makes the script fail/exit when
#   - A command fails
#   - Accessing an unset variable
#   - One command in a pipeline fails
# set -o errexit
# set -o nounset
# set -o pipefail

# Global variables
PROGNAME=$(basename "$0")
PROGDIR=$(dirname "$0")
ARGS="$@"

# Main script instructions
main() 
{
    grep -irns $2$ $1 || grep -irns "'$2'" $1 
}

# Run the script
main $ARGS
