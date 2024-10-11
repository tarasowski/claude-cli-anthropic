#!/bin/bash

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 '<first_argument>'"
    exit 1
fi

# Store the first argument
FIRST_ARGUMENT=$1

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
    --arg content "$FIRST_ARGUMENT" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        messages: [
            {role: $role, content: $content}
        ]
    }')

# Make the API request and capture both response body and status code
response=$(curl -s -w "%{http_code}" -H "x-api-key: $API_KEY" \
    -H "anthropic-version: $VERSION" \
    -H "content-type: $CONTENT_TYPE" \
    --data "$JSON_DATA" \
    "$URL")

# Separate the response body and the status code by using the length of the response
response_body="${response%???}"  # Get everything except the last three characters which are the status code
status_code="${response: -3}"     # Get the last three characters as the status code

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
