#!/bin/bash
source config.env
source common.env
source params.env
source libs/json.sh

get_params() {
  local filter="grep -E \"^("

  local idx=0
  for param in "$@"; do
    filter+="$param"
    if [ $idx -lt $(($#-1)) ]; then
      filter+="|"
    fi
    idx=$((idx+1))
  done

  filter+="),\""

  # Filter the output of 'ldvs' command and return the filtered lines
  printf "%s\n" "$($ldvs | eval "$filter")"
}

# decide on a list of params to send
use_ondemand_params=false
minute=$(date +%M)
use_slow_params=$((minute % 5 == 0))

# if script is ran with --full argument, send all params at once
if [ "$1" == "--full" ]; then
  use_ondemand_params=true
fi

# update different parameters with a different frequency
params_output=""
if [ $use_ondemand_params == true ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}" "${ondemand_params[@]}")
elif [ $use_slow_params == 1 ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}")
else
  params_output+=$(get_params "${fast_params[@]}")
fi

# Check if ldvs/grep command exited successfully before proceeding
if [ $? -ne 0 ]; then
  echo "Error: ldvs command failed."
  exit 1
fi

# Generate the JSON document
json="{"
first=true
while IFS=',' read -ra line; do
  key="${line[0]}"
  value="${line[1]}"

  if [ "$first" = true ]; then
    first=false
  else
    json+=", "
  fi
  json+=$(line2json "$key" "$value")
done <<< "$params_output"
json+="}"

# Debug print JSON
if [ "$LOCAL_DEBUG" = 1 ]; then
  echo $json
fi

# Calculate basic http auth using base64 of vincode + sha256(password)
HASHED_PWD=$(shasum -a 256 <<< "$PASSWORD" | awk '{print $1}' | tr -d "\n")
BASIC_AUTH=$(echo -n "$VINCODE:$HASHED_PWD" | base64 | tr -d "\n")

# Send the JSON document as a POST request, to the metrics endpoint
curl $CURL_OPTS -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Basic $BASIC_AUTH" \
     -d "$json" \
     $METRICS_ENDPOINT



