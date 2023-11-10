#!/bin/bash



# Functions

function check_dependencies {

    for cmd in docker jq wget python3; do

        if ! command -v $cmd &> /dev/null; then

            echo "Error: $cmd is not installed."

            exit 1

        fi

    done

}



function start_docker_container {

    echo "Starting Docker container..."

    CONTAINER_ID=$(docker run -d node:latest tail -f /dev/null)

    if [ -z "$CONTAINER_ID" ]; then

        echo "Error: Failed to start Docker container."

        exit 1

    fi

    echo "Docker container started with ID: $CONTAINER_ID"

}



function install_npm_package {

    echo "Initializing npm and installing package..."

    docker exec $CONTAINER_ID sh -c "cd /root && npm init -y > /dev/null && npm install $PACKAGE@$VERSION" 2> $OUTPUT_DIR/npm_warnings.txt

    if [ $? -ne 0 ]; then

        echo "Error: Failed to install npm package."

        exit 1

    fi

    # Ensure package-lock.json exists

    docker exec $CONTAINER_ID sh -c "cd /root && npm i --package-lock-only"

    echo "Package installed successfully!"

}



function check_vulnerabilities {

    echo "Checking for vulnerabilities..."

    VULN_OUTPUT=$(docker exec $CONTAINER_ID npm audit --json)

    echo "$VULN_OUTPUT" > $OUTPUT_DIR/vulnerabilities.json  # Save the output to a file

    VULN_COUNT=$(echo $VULN_OUTPUT | jq .metadata.vulnerabilities.total)

    if ! [[ $VULN_COUNT =~ ^[0-9]+$ ]]; then

        VULN_COUNT=0

        echo "Unable to determine the number of vulnerabilities."

    else

        echo "Found $VULN_COUNT vulnerabilities!"

        if [ "$VULN_COUNT" -gt 0 ]; then

            echo "Converting vulnerabilities to CSV format..."

            convert_json_to_csv "$OUTPUT_DIR/vulnerabilities.json" "$OUTPUT_DIR/vulnerabilities.csv"

        fi

    fi

}



function convert_json_to_csv {

    local json_file=$1

    local csv_file=$2

    # Assuming the JSON structure is known and flat, use jq to parse and convert

    # You might need to adjust the jq filter based on the actual structure of your vulnerabilities.json

    jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' "$json_file" > "$csv_file"

}



function extract_urls {

    grep -oP '"resolved": "\K[^"]+.tgz' $OUTPUT_DIR/package-lock.json > $OUTPUT_DIR/npm.txt

    sort -u $OUTPUT_DIR/npm.txt -o $OUTPUT_DIR/npm.txt

    echo "URLs to be downloaded:"

    cat $OUTPUT_DIR/npm.txt

}



function download_files {

    while read url; do

        echo "Downloading: $url"

        wget -P $DIR_NAME $url

    done < $OUTPUT_DIR/npm.txt

}



# Main script

check_dependencies



if [ "$#" -lt 2 ]; then

    echo "Usage: $0 <npm_package> [version] <6-digit-identifier>"

    exit 1

fi



PACKAGE=$1



if [[ "$#" == 3 ]]; then

    VERSION=$2

    IDENTIFIER=$3

else

    VERSION=latest

    IDENTIFIER=$2

fi



# Ensure the identifier is numeric and 6 digits

if ! [[ $IDENTIFIER =~ ^[0-9]{6}$ ]]; then

    echo "Error: Identifier must be a 6-digit number."

    exit 1

fi



OUTPUT_DIR=~/Downloads

DIR_NAME="$OUTPUT_DIR/WO$IDENTIFIER"

mkdir -p $DIR_NAME



start_docker_container

trap 'docker rm -f $CONTAINER_ID' EXIT



install_npm_package

check_vulnerabilities

docker cp $CONTAINER_ID:/root/package-lock.json $OUTPUT_DIR/package-lock.json

extract_urls

download_files



echo "Script completed successfully!"

