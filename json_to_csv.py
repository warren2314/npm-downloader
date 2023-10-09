import json
import csv
import sys

def audit_json_to_csv(json_filename):
    with open(json_filename, 'r') as f:
        data = json.load(f)

    # Prepare CSV data
    csv_data = []
    vulnerabilities = data['vulnerabilities']

    for vuln in vulnerabilities.values():
        name = vuln['name']
        severity = vuln['severity']
        title = ""
        url = ""

        # Some vulnerabilities have a direct link, others are nested. We'll handle both.
        for v in vuln['via']:
            if isinstance(v, dict):
                title = v.get('title', '')
                url = v.get('url', '')
            csv_data.append([name, severity, title, url])

    # Write to CSV
    csv_writer = csv.writer(sys.stdout)  # Writing to stdout, so it can be redirected to a file from the shell script
    csv_writer.writerow(['Package Name', 'Severity', 'Vulnerability Title', 'URL'])  # Header
    csv_writer.writerows(csv_data)

if __name__ == "__main__":
    json_filename = sys.argv[1]
    audit_json_to_csv(json_filename)

