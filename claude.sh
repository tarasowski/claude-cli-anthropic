#!/bin/bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# Display a small progress spinner in bash while running your commands with an     #
# optional message.                                                                #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Draw Spinner                                                                     #
# -------------------------------------------------------------------------------- #
# Draw the actual spinner on the screen, suffixed by the message (if given). This  #
# function will sit in an infinite loop as the stop script is used to terminate    #
# the function.                                                                    #
#                                                                                  #
# NOTE: Do not call this function directly!                                        #
# -------------------------------------------------------------------------------- #

function draw_spinner()
{
    # shellcheck disable=SC1003
    local -a marks=( '/' '-' '\' '|' )
    local i=0

    delay=${SPINNER_DELAY:-0.25}
    message=${1:-}

    while :; do
        printf '%s\r' "${marks[i++ % ${#marks[@]}]} ${message}"
        sleep "${delay}"
    done
}

# -------------------------------------------------------------------------------- #
# Start Spinner                                                                    #
# -------------------------------------------------------------------------------- #
# A wrapper for starting the spiner, it will pass the message if supplied, and     #
# store the PID of the process for later termination.                              #
# -------------------------------------------------------------------------------- #

function start_spinner()
{
    message=${1:-}                                # Set optional message

    draw_spinner "${message}" &                   # Start the Spinner:

    SPIN_PID=$!                                   # Make a note of its Process ID (PID):

    #declare -g SPIN_PID

    # shellcheck disable=SC2312
    trap stop_spinner $(seq 0 15)
}

# -------------------------------------------------------------------------------- #
# Draw Spinner Eval                                                                #
# -------------------------------------------------------------------------------- #
# Draw the actual spinner on the screen, after evaluating the command to use the   #
# result as the message, function will sit in an infinite loop as the stop script  #
# is used to terminate the function.                                               #
#                                                                                  #
# NOTE: Do not call this function directly!                                        #
# -------------------------------------------------------------------------------- #

function draw_spinner_eval()
{
    # shellcheck disable=SC1003
    local -a marks=( '/' '-' '\' '|' )
    local i=0

    delay=${SPINNER_DELAY:-0.25}
    message=${1:-}

    while :; do
        message=$(eval "$1")
        printf '%s\r' "${marks[i++ % ${#marks[@]}]} ${message}"
        sleep "${delay}"
        printf '\033[2K'
    done
}

# -------------------------------------------------------------------------------- #
# Start Spinner Eval                                                               #
# -------------------------------------------------------------------------------- #
# A wrapper for starting the spiner, it will pass the command to be evaluated, and #
# store the PID of the process for later termination.                              #
# -------------------------------------------------------------------------------- #

function start_spinner_eval()
{
    command=${1}                                  # Set the command

    if [[ -z "${command}" ]]; then
        echo "You MUST supply a command"
        exit
    fi

    draw_spinner_eval "${command}" &              # Start the Spinner:

    SPIN_PID=$!                                   # Make a note of its Process ID (PID):

    declare -g SPIN_PID

    # shellcheck disable=SC2312
    trap stop_spinner $(seq 0 15)
}

# -------------------------------------------------------------------------------- #
# Stop Spinner                                                                     #
# -------------------------------------------------------------------------------- #
# A wrapper for stopping the spinner, this simply kills off the process.           #
# -------------------------------------------------------------------------------- #

function stop_spinner()
{
    if [[ "${SPIN_PID}" -gt 0 ]]; then
        kill -9 "${SPIN_PID}" > /dev/null 2>&1;
    fi
    SPIN_PID=0
    printf '\033[2K'
}

# -------------------------------------------------------------------------------- #
# End of Script                                                                    #
# -------------------------------------------------------------------------------- #
# This is the end - nothing more to see here.                                      #
# -------------------------------------------------------------------------------- #


# Check if there are any arguments
if [ $# -eq 0 ]; then
    echo "Usage: mybash.sh <question> or cat file.txt | mybash.sh"
    exit 1
fi

# If input is from stdin (cat file.txt | mybash.sh)
if [ -t 0 ]; then
    # No piped input, use the argument as the question
    question="$1"
    content=""
else
    # Read the piped input (file contents)
    content=$(cat)
    # Combine with the question
    question="$content \n\n $1"
fi

# Define API endpoint and headers
URL="https://api.anthropic.com/v1/messages"
API_KEY=$ANTHROPIC_API_KEY  # Ensure the ANTHROPIC_API_KEY is set in your environment
VERSION="2023-06-01"
CONTENT_TYPE="application/json"

# Prepare the JSON data
JSON_DATA=$(jq -n \
    --arg model "claude-3-5-sonnet-20240620" \
    --argjson max_tokens 1024 \
    --arg role "user" \
    --arg content "$question" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        messages: [
            {role: $role, content: $content}
        ]
    }')

start_spinner "Fetching response from the API..."  # Start the spinner
# Make the API request and capture both response body and status code
response=$(curl -s -w "%{http_code}" -H "x-api-key: $API_KEY" \
    -H "anthropic-version: $VERSION" \
    -H "content-type: $CONTENT_TYPE" \
    --data "$JSON_DATA" \
    "$URL")

# Separate the response body and the status code by using the length of the response
response_body="${response%???}"  # Get everything except the last three characters which are the status code
status_code="${response: -3}"     # Get the last three characters as the status code

stop_spinner  # Stop the spinner
# Check the HTTP response code
if [ "$status_code" -eq 200 ]; then
    # Use jq to extract the "text" field from the content array
    content_text=$(echo "$response_body" | jq -r '.content[0].text')
    echo "$content_text"  # Print the actual content text
else
    echo "Request failed with status code: $status_code"
    echo "Response body:"
    echo "$response_body"  # Print the response body even if there was an error
fi
