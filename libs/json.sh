# Function to generate JSON object from a key-value pair
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
