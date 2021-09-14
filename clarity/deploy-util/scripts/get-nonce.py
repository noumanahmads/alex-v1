#!/usr/bin/env python3
import subprocess
import os
import json

res = subprocess.check_output(f"cat ../hex-files/get-nonce/get-nonce1.hex | xxd -p -r | curl -H \"Content-Type: application/octet-stream\" -X POST --data-binary @- https://regtest-2.alexgo.io/v2/transactions", shell=True)
print(res)
data = json.loads(res)
expected_nonce = data['reason_data']['expected']
print(f"Nonce is {expected_nonce}")