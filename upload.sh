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

# update different parameters with a different frequency
params_output=""
hour=$(date +%H)
minute=$(date +%M)

if [ $hour == "23" ] && [ $minute == "59" ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}" "${eventual_params[@]}")
elif [ $((minute % 5)) == 0 ]; then
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
HASHED_PWD=$(printf "%s" "$PASSWORD" | shasum -a 256 | awk '{print $1}')
BASIC_AUTH=$(echo -n "$VINCODE:$HASHED_PWD" | base64 | tr -d "\n")

# Send the JSON document as a POST request, to the metrics endpoint
curl $CURL_OPTS -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Basic $BASIC_AUTH" \
     -d "$json" \
     $METRICS_ENDPOINT



