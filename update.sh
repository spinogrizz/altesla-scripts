# if run with -f flag — force update
# otherwise check if it's 4AM and execute only 1 in 5 times
if [[ "$1" == "-f" ]] || 
   { [[ "$(date +%H%M)" == "0401" ]] && [[ $(( RANDOM % 5 + 1 )) -eq 1 ]]; }; then
    echo "Checking for updates..."
else
    exit 1
fi

# configuration and common code
source config.env
source common.sh

# URLs and headers
UPDATE_URL="${BASE_API}/update/${UPDATES_BRANCH}"
METRICS_ENDPOINT=${BASE_API}/metrics
AUTH="Authorization: Basic $BASIC_AUTH"

# Filenames
TAR_FILE="update.tar"
SIG_FILE="update.tar.sig"
VERSION_FILE="version"
TMP_DIR="tmp"

# Function to remove downloaded files on script exit
cleanup() {
    rm -rf $TMP_DIR 
}

# Trap any form of script exit
trap cleanup EXIT

# Check for updates
UPDATE_VERSION=$(curl -H "$AUTH" -s $UPDATE_URL/$VERSION_FILE)
CURRENT_VERSION=$(cat $VERSION_FILE)

if (( UPDATE_VERSION > CURRENT_VERSION )); then
    echo "New version ${UPDATE_VERSION} available. Starting update."

    # Create a tmp directory for downloads if it doesn't exist
    mkdir -p $TMP_DIR

    # Download the tarball and the signature file
    curl -H "$AUTH" -s -o $TMP_DIR/$TAR_FILE $UPDATE_URL/$TAR_FILE
    curl -H "$AUTH" -s -o $TMP_DIR/$SIG_FILE $UPDATE_URL/$SIG_FILE

    # Check files exist and are not empty
    if [[ ! -s $TMP_DIR/$TAR_FILE ]] || [[ ! -s $TMP_DIR/$SIG_FILE ]]; then
        exit 1
    fi

    # Verify the signature
    if openssl dgst -sha256 -verify update.pub.pem -signature $TMP_DIR/$SIG_FILE $TMP_DIR/$TAR_FILE; then
        echo "Signature is valid. Replacing files."

        # Extract the new files from the tarball
        tar -xvf $TMP_DIR/$TAR_FILE -C .

        # Update the version file
        echo $UPDATE_VERSION > $VERSION_FILE

        # Make the scripts executable
        chmod +x *.sh

        # Send the new version to the metrics endpoint
        curl $CURL_OPTS \
            -H "Content-Type: application/json" \
            -H "Authorization: Basic $BASIC_AUTH" \
            -d "{\"version\": $UPDATE_VERSION}" \
            $METRICS_ENDPOINT
    else
        echo "Signature is not valid. Update aborted."
    fi
fi