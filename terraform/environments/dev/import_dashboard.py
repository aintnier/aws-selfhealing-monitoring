import json
import urllib.request
import urllib.parse
import base64
import os

url_base = "http://16.22.20.11:3000"
username = "admin"
password = """&'8wz9XSk"S+vEG"""
auth = f"{username}:{password}"
base64_auth = base64.b64encode(auth.encode('utf-8')).decode('utf-8')
headers = {
    'Content-Type': 'application/json',
    'Authorization': f'Basic {base64_auth}'
}

# 1. Fetch Datasource UID
req_ds = urllib.request.Request(f"{url_base}/api/datasources", headers=headers)
try:
    with urllib.request.urlopen(req_ds) as response:
        datasources = json.loads(response.read().decode('utf-8'))
        cw_ds = next((ds for ds in datasources if ds['name'] == 'CloudWatch'), None)
        if not cw_ds:
            print("CloudWatch datasource not found!")
            exit(1)
        uid = cw_ds['uid']
except Exception as e:
    print(f"Error fetching datasources: {e}")
    exit(1)

# 2. Load and modify dashboard JSON
with open('dashboard.json', 'r') as f:
    dashboard_data = json.load(f)

# Update UIDs
for panel in dashboard_data.get('panels', []):
    if 'datasource' in panel and panel['datasource'].get('uid') == 'CloudWatch':
        panel['datasource']['uid'] = uid
    if 'targets' in panel:
        for target in panel['targets']:
            if 'datasource' in target and target['datasource'].get('uid') == 'CloudWatch':
                target['datasource']['uid'] = uid

for template in dashboard_data.get('templating', {}).get('list', []):
    if 'datasource' in template and template['datasource'].get('uid') == 'CloudWatch':
        template['datasource']['uid'] = uid
    if template.get('name') == 'InstanceId':
        template['includeAll'] = False
        template['current'] = {} # Reset current selection so it picks the first one

# 3. Upload dashboard
payload = {
    "dashboard": dashboard_data,
    "overwrite": True
}
data = json.dumps(payload).encode('utf-8')

req_upload = urllib.request.Request(f"{url_base}/api/dashboards/db", data=data, headers=headers)
try:
    with urllib.request.urlopen(req_upload) as response:
        result = json.loads(response.read().decode('utf-8'))
        print(f"Success! Dashboard URL: {result.get('url')}")
except Exception as e:
    print(f"Error uploading dashboard: {e}")
    if hasattr(e, 'read'):
        print(e.read().decode('utf-8'))
