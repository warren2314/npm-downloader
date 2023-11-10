import json
import csv
import sys

def audit_json_to_csv(json_data):
    data = json.loads(json_data)

    csv_data = []
    vulnerabilities = data['vulnerabilities']

    for vuln in vulnerabilities.values():
        name = vuln['name']
        severity = vuln['severity']
        title = ""
        url = ""

        for v in vuln['via']:
            if isinstance(v, dict):
                title = v.get('title', '')
                url = v.get('url', '')
            csv_data.append([name, severity, title, url])

    csv_writer = csv.writer(sys.stdout)
    csv_writer.writerow(['Package Name', 'Severity', 'Vulnerability Title', 'URL'])
    csv_writer.writerows(csv_data)

if __name__ == "__main__":
    json_data = sys.argv[1]
    audit_json_to_csv(json_data)
