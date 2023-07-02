#!/bin/bash

PRIVATE_KEY="dist/sign.pem"
FILES=("version" "main.sh" "command.sh" "send.sh" "common.sh" "update.sh" "update.pub.pem" "params.env" "config.env.example")
TAR_FILE="update.tar"
SIG_FILE="update.tar.sig"

# Go to the root folder
cd ..

# Create a tarball of the files
tar --exclude='._*' -cvf $TAR_FILE "${FILES[@]}"

# Sign the tarball using the private key
openssl dgst -sha256 -sign $PRIVATE_KEY -out $SIG_FILE $TAR_FILE

# Print the output files
ls -lha $TAR_FILE $SIG_FILE

# Move file to dist folder replacing the old ones
mv $TAR_FILE dist/
mv $SIG_FILE dist/

# Go back to dist folder
cd dist