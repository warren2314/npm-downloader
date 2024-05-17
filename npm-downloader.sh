#!/bin/bash



# Functions

function check_dependencies {

    for cmd in docker jq wget python3 npm; do

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



function process_package {

    local pkg_line=$1

    local pkg="${pkg_line%@*}"  # Extract everything before the last '@'

    local ver="${pkg_line##*@}"  # Extract everything after the last '@'



    echo "Initializing npm and installing package $pkg@$ver..."

    docker exec $CONTAINER_ID sh -c "cd /root && npm init -y > /dev/null && npm install $pkg@$ver --package-lock-only" 2> $OUTPUT_DIR/npm_warnings.txt

    if [ $? -ne 0 ]; then

        echo "Error: Failed to install npm package $pkg@$ver."

        exit 1

    fi

    echo "Package $pkg@$ver installed successfully!"

    if ! docker exec $CONTAINER_ID test -f /root/package-lock.json; then

        echo "Error: package-lock.json not found, cannot perform audit."

        exit 1

    fi

    docker cp $CONTAINER_ID:/root/package-lock.json $OUTPUT_DIR/package-lock.json

    check_vulnerabilities

    extract_urls

    download_files

}



function check_vulnerabilities {

    echo "Checking for vulnerabilities..."

    local vuln_file="$OUTPUT_DIR/npm_audit_$WO_NUMBER.json"  # Specify the file name for audit results

    docker exec $CONTAINER_ID npm audit --json > "$vuln_file"

    if [ $? -ne 0 ]; then

        echo "Error: npm audit failed."

        exit 1

    fi

    echo "Vulnerability report saved to $vuln_file"

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



while getopts "i:f:p:" opt; do

    case "$opt" in

        i) interactive_mode=1 ;;

        f) file="$OPTARG" ;;

        p) package="$OPTARG" ;;

    esac

done



echo "Please enter a 6-digit WO number:"

read WO_NUMBER



# Validate WO_NUMBER

if ! [[ $WO_NUMBER =~ ^[0-9]{6}$ ]]; then

    echo "Error: WO number must be a 6-digit number."

    exit 1

fi



OUTPUT_DIR=~/Downloads

DIR_NAME="$OUTPUT_DIR/WO$WO_NUMBER"

mkdir -p $DIR_NAME



start_docker_container

trap 'docker rm -f $CONTAINER_ID' EXIT



if [[ $interactive_mode ]]; then

    echo "Entering interactive mode. Type 'exit' to quit."

    while true; do

        read -p "Enter package and version (Format: package@version): " pkg

        [[ "$pkg" == "exit" ]] && break

        process_package "$pkg"

    done

elif [[ -n $file ]]; then

    # File exists, read line by line

    while IFS= read -r line || [[ -n "$line" ]]; do

        process_package "$line"

    done < "$file"

elif [[ -n $package ]]; then

    # Treat as a single package input

    process_package "$package"

else

    echo "No valid operation mode selected. Use -i for interactive, -f for file input, or -p for a single package."

    exit 1

fi



echo "Script completed successfully!"

