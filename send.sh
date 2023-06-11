#!/bin/bash

### SEND METRICS TO THE API ###
### DO NOT MODIFY THIS FILE ###

# configuration
source config.env
source params.env

# common code
source common.sh

METRICS_ENDPOINT=${BASE_API}/metrics

# Function to filter the output of 'ldvs' command and return the filtered lines
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

  printf "%s\n" "$($ldvs | eval "$filter")"
}

# Function to convert a line of output from 'ldvs' command to json format
line2json() {
  key="$1"
  value="$2"
  res=""

  # null value
  if [[ "$value" == "@invalid" ]] || [[ "$value" == "--" ]] || [[ "$value" == "none" ]]; then
    res="null"

  # boolean values
  elif [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
    res="$value"
  elif [[ "$value" == "ON" ]]; then
    res="true"
  elif [[ "$value" == "OFF" ]]; then
    res="false"

  # numeric values
  elif [[ "$value" =~ ^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$ ]]; then
    res="$value"

  # string values
  else
    res="\"$value\""
  fi

  echo "\"$key\": $res"
}

# Determine the parameters to be sent to the API based on the current time
params_output=""
hour=$(date +%H)
minute=$(date +%M)

# Check if the current time is 23:59, if so, send all parameters
if [ $hour == "23" ] && [ $minute == "59" ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}" "${eventual_params[@]}")

# Send partial parameters based every 5 minutes
elif [ $((minute % 5)) == 0 ]; then
  params_output+=$(get_params "${fast_params[@]}" "${slow_params[@]}")

# Send only frequently changed parameters every minute
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

# Send the JSON document as a POST request, to the metrics endpoint
curl $CURL_OPTS -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Basic $BASIC_AUTH" \
     -d "$json" \
     $METRICS_ENDPOINT
