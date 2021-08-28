#!/usr/bin/env python3
import subprocess
import os
import json

meta_data = {"Contracts": []}
address = ""
with open('deploy_keychain.json') as file:
    data = json.load(file)
    address = data['keyInfo']['address']

contract_array = []

versioning = ""
print('Type Contract Series')
# versioning += "-"
series = input("-")

print('Type Developer Name')
developer = input("-")

print('Type Contract Version Number')
version = input("-")

version_folder = series + "-" + developer + "-" + version
series_and_developer = "-" + series + "-" + developer

res = subprocess.check_output(f"cat ./hex-files/get-nonce/get-nonce.hex | xxd -p -r | curl -H \"Content-Type: application/octet-stream\" -X POST --data-binary @- https://stacks-node-api.regtest.stacks.co/v2/transactions", shell=True)
data = json.loads(res)
expected_nonce = data['reason_data']['expected']
print(f"Nonce is {expected_nonce}")
os.mkdir(f'./hex-files/{version_folder}')

nonce = expected_nonce
contracts = r'./contracts'
for file in os.listdir(contracts):
    clarity_name = file.split('.')[0]
    print(clarity_name)
    full_contract_name = clarity_name + version_folder
    contract_name_json = clarity_name + series_and_developer
    res1 = subprocess.check_output(f"stx deploy_contract -x -t ./contracts/{clarity_name}.clar {full_contract_name} 50000 {nonce} $(cat ./deploy_keychain.json | jq -r .keyInfo.privateKey) > ./hex-files/{version_folder}/{full_contract_name}.hex", shell=True)
    txid = subprocess.check_output(f"cat ./hex-files/{version_folder}/{full_contract_name}.hex | xxd -p -r | curl -H \"Content-Type: application/octet-stream\" -X POST --data-binary @- https://stacks-node-api.regtest.stacks.co/v2/transactions", shell=True)
    print(txid)
    meta_data['Contracts'].append({"name": contract_name_json, "version": version, "deployer": address, "txid": "0x"+txid.decode('utf-8').strip('"')})
    nonce += 1

print(meta_data)

with open(f'./contract-records/{version_folder}.json', 'w') as f:
    json.dump(meta_data, f)