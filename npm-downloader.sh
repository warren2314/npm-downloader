#!/bin/bash

# Check if package name and 6-digit identifier are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <npm_package> [version] <6-digit-identifier>"
    exit 1
fi

PACKAGE=$1

# Check if version is provided, else set default to 'latest'
if [[ "$#" == 3 ]]; then
    VERSION=$2
    IDENTIFIER=$3
else
    VERSION=latest
    IDENTIFIER=$2
fi

# Set the output directory to ~/Downloads
OUTPUT_DIR=~/Downloads

# Start a Docker container with node:latest
CONTAINER_ID=$(docker run -d node:18 tail -f /dev/null)

# Handle container cleanup on exit
function cleanup {
    docker rm -f $CONTAINER_ID
}
trap cleanup EXIT

# Install the package and save npm warnings to ~/Downloads/npm_warnings.txt
docker exec $CONTAINER_ID sh -c "cd /root && npm install $PACKAGE@$VERSION" 2> $OUTPUT_DIR/npm_warnings.txt

# Check for vulnerabilities
VULN_OUTPUT=$(docker exec $CONTAINER_ID npm audit --json)
VULN_COUNT=$(echo $VULN_OUTPUT | jq .metadata.vulnerabilities.total)

echo "Number of vulnerabilities found: $VULN_COUNT"

# If vulnerabilities exist, save the output to ~/Downloads/audit_output.json and convert to CSV 
if [ "$VULN_COUNT" -gt "0" ]; then
    echo $VULN_OUTPUT > $OUTPUT_DIR/audit_output.json
    python3 json_to_csv.py $OUTPUT_DIR/audit_output.json > $OUTPUT_DIR/audit_output.csv
fi

# Extract the package-lock.json to ~/Downloads
docker cp $CONTAINER_ID:/root/package-lock.json $OUTPUT_DIR/package-lock.json

# Process the package-lock.json to extract the URLs and save to ~/Downloads/npm.txt
python3 extract_urls.py $OUTPUT_DIR/package-lock.json > $OUTPUT_DIR/npm.txt

# Log all URLs that will be downloaded
echo "URLs to be downloaded:"
cat $OUTPUT_DIR/npm.txt

# Create a directory named WO followed by the provided 6 digits inside ~/Downloads
DIR_NAME="$OUTPUT_DIR/WO$IDENTIFIER"
mkdir -p $DIR_NAME

# wget each URL in ~/Downloads/npm.txt inside the WO<6-digit-identifier> directory
while read url; do
    echo "Downloading: $url"
    wget -P $DIR_NAME $url
done < $OUTPUT_DIR/npm.txt

