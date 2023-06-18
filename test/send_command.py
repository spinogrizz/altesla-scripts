#!/usr/bin/env python3

import argparse
import requests
import hashlib
import base64
import secrets
import json

# 1. Constants
VIN = "5YJ3E1EA6KF123456"
PASSWORD = "qwerty1234"

# 2. Command line arguments
parser = argparse.ArgumentParser(description='Send API Request.')
parser.add_argument('command', type=str, help='Command to send.')
parser.add_argument('argument', type=str, help='Argument to send.')
args = parser.parse_args()

# 3. Authorization
hash_object = hashlib.sha256(PASSWORD.encode('utf-8'))
hashed_password = hash_object.hexdigest()
authorization = base64.b64encode(f"{VIN}:{hashed_password}".encode('utf-8')).decode('utf-8')

# 4. UUID
uuid = secrets.token_hex(8)  # 8 bytes for a short hex

# 5. cmd and arg
cmd = args.command
arg = args.argument

# 6. Key
key_object = hashlib.sha256(f"{uuid}{cmd}{arg}{PASSWORD}".encode('utf-8'))
key = key_object.hexdigest()

# Construct JSON payload
payload = {
	"uuid": uuid,
	"cmd": cmd,
	"arg": arg,
	"key": key
}

# Headers
headers = {
	'Authorization': 'Basic ' + authorization,
	'Content-Type': 'application/json'
}

# POST request
response = requests.post('http://localhost:3000/commands', data=json.dumps(payload), headers=headers)

# Print response

if response.status_code == 202:
	print("Command sent successfully")
else:
	print("Error white sending command")