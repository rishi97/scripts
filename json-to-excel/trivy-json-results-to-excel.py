import json
import glob
import pandas as pd

def extract_data_from_json(json_file):
    """Extracts relevant data from a JSON file and returns it as a dictionary."""
    with open(json_file, 'r') as f:
        data = json.load(f)

    vulnerabilities = []
    if 'Results' in data:
        for result in data['Results']:
            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    vuln_info = {
                        'Image': data['ArtifactName'],
                        'Target': result['Target'],
                        'VulnerabilityID': vuln.get('VulnerabilityID'),
                        'PkgName': vuln.get('PkgName'),
                        'InstalledVersion': vuln.get('InstalledVersion'),
                        'FixedVersion': vuln.get('FixedVersion', 'N/A'),
                        'Severity': vuln.get('Severity'),
                        'PrimaryURL': vuln.get('PrimaryURL'),
                        'Description': vuln.get('Description')
                    }
                    vulnerabilities.append(vuln_info)
    return vulnerabilities

def write_data_to_excel(vulnerabilities, excel_file):
    """Writes the extracted data to an Excel file."""
    df = pd.DataFrame(vulnerabilities)
    df.to_excel(excel_file, index=False)

def main():
    """Main function to process all JSON files in the directory and write the data to Excel."""
    scan_results_dir = 'trivy_scan_json'  # Replace with your directory path
    excel_file = 'new_consolidated_trivy_scan_results.xlsx'  # Replace with your desired Excel file name

    all_vulnerabilities = []
    for json_file in glob.glob(f"{scan_results_dir}/*.json"):
        vulnerabilities = extract_data_from_json(json_file)
        all_vulnerabilities.extend(vulnerabilities)

    write_data_to_excel(all_vulnerabilities, excel_file)

if __name__ == '__main__':
    main()
