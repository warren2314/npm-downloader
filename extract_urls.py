import json
import sys

def extract_urls(filename):
    with open(filename, 'r') as f:
        data = json.load(f)

    urls = set()
    for key, value in data["dependencies"].items():
        if "resolved" in value:
            urls.add(value["resolved"])

    return urls

if __name__ == "__main__":
    filename = sys.argv[1]
    urls = extract_urls(filename)
    for url in urls:
        print(url)

