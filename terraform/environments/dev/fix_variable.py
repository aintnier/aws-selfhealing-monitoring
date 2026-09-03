import json

with open('dashboard.json', 'r') as f:
    d = json.load(f)

for t in d.get('templating', {}).get('list', []):
    if t.get('name') == 'InstanceId':
        t['query'] = 'ec2_instance_attribute(eu-south-1, InstanceId, {"instance-state-name":["running"]})'
        t['definition'] = t['query']

with open('dashboard.json', 'w') as f:
    json.dump(d, f, indent=2)
