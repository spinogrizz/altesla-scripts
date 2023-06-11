if command -v sha256sum > /dev/null
then
  sha256sum "$1"
elif command -v shasum > /dev/null
then
  shasum -a 256 "$1"
else
  exit 1
fi