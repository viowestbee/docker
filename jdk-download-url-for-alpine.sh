#!/bin/sh

# Check if an argument was passed to the script
# If an argument was passed, set JAVA_VERSION to the value of the argument
# If no argument was passed, check if JAVA_VERSION is already set. If it's not set, exit the script with an error message
if [ $# -eq 1 ]; then
    JAVA_VERSION=$1
elif [ -z "$JAVA_VERSION" ]; then
    echo "Error: No Java version specified. Please set the JAVA_VERSION environment variable or pass the version as an argument." >&2
    exit 1
fi

# Check if jq and curl are installed
# If they are not installed, exit the script with an error message
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "jq and curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

# Replace underscores with plus signs in JAVA_VERSION
ARCHIVE_DIRECTORY=$(echo "$JAVA_VERSION" | tr '_' '+')

# URL encode ARCHIVE_DIRECTORY
ENCODED_ARCHIVE_DIRECTORY=$(echo "$ARCHIVE_DIRECTORY" | xargs -I {} printf %s {} | jq "@uri" -jRr)

# Convert the architecture name to the format used by the Adoptium API
CONVERTED_ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/')

# Fetch the download URL from the Adoptium API
# https://api.adoptium.net/q/swagger-ui/#/Binary/getBinaryByVersion
# We're supposed to add a c_lib parameter to the URL, but the Adoptium API doesn't seem to like it (returning an error)
# curl -X 'GET' \
#  'https://api.adoptium.net/v3/binary/version/jdk-11.0.22%2B7/alpine-linux/x64/jdk/hotspot/normal/eclipse?c_lib=musl&project=jdk' \
#  -H 'accept: */*'
#{"errorMessage":"No releases match the request"}
if ! RESPONSE=$(curl -fsI "https://api.adoptium.net/v3/binary/version/jdk-${ENCODED_ARCHIVE_DIRECTORY}/alpine-linux/${CONVERTED_ARCH}/jdk/hotspot/normal/eclipse?project=jdk"); then
    echo "Error: Failed to fetch the URL. Exiting with status 1." >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Extract the redirect URL from the HTTP response
REDIRECTED_URL=$(echo "$RESPONSE" | grep Location | awk '{print $2}' | tr -d '\r')

# If no redirect URL was found, exit the script with an error message
if [ -z "$REDIRECTED_URL" ]; then
    echo "Error: No redirect URL found. Exiting with status 1." >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Use curl to check if the URL is reachable
# If the URL is reachable, print the URL
# If the URL is not reachable, print an error message and exit the script with status 1
if ! curl -v -fs "$REDIRECTED_URL" >/dev/null 2>&1; then
    echo "${REDIRECTED_URL}" is not reachable. >&2
    exit 1
else
    echo "$REDIRECTED_URL"
fi