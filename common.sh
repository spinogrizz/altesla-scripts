# Debug mode
if [ "$LOCAL_DEBUG" = 1 ]; then
  ldvs="cat test/ldvs.txt"
  VINCODE="5YJ3E1EA6KF123456"

  METRICS_ENDPOINT=http://localhost:3000/metrics
  COMMAND_ENDPOINT=http://localhost:3000/commands

  CURL_OPTS="-vvvv"
  SHA256CMD="shasum -a 256" # macOS compatible
else
  ldvs="ldvs"
  VINCODE=$(cat /var/etc/vin)
  SHA256="sha256sum"
fi

# Calculate basic http auth using base64 of vincode + sha256(password)
HASHED_PWD=$(printf "%s" "$PASSWORD" | ${SHA256CMD} | awk '{print $1}')
BASIC_AUTH=$(echo -n "$VINCODE:$HASHED_PWD" | base64 | tr -d "\n")
