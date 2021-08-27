#!/usr/bin/env python3
import subprocess
import os
import json

meta_data = {}

with open('deploy_keychain.json') as file:
    data = json.load(file)
    meta_data['address'] = data['keyInfo']['address']

contract_array = []

versioning = ""
print('Type Contract Series')
versioning += "-"
versioning += input("-")
print('Type Developer Name')
versioning += "-"
versioning += input("-")
print('Type Contract Version Number')
versioning += "-"
versioning += input("-")

os.mkdir(f'./hex-files/{versioning[1:]}')
#subprocess.check_output(f'mkdir ./hex-files/{versioning[1:]}')

nonce = 128
contracts = r'./contracts'
for file in os.listdir(contracts):
    clarity_name = file.split('.')[0]
    full_contract_name = clarity_name + versioning
    res1 = subprocess.check_output(f"stx deploy_contract -x -t ./contracts/{clarity_name}.clar {full_contract_name} 2000 {nonce} $(cat ./deploy_keychain.json | jq -r .keyInfo.privateKey) > ./hex-files/{versioning[1:]}/{full_contract_name}.hex", shell=True)
    print(res1)
    txid = subprocess.check_output(f"cat ./hex-files/{versioning[1:]}/{full_contract_name}.hex | xxd -p -r | curl -H \"Content-Type: application/octet-stream\" -X POST --data-binary @- https://stacks-node-api.regtest.stacks.co/v2/transactions", shell=True)
    print(txid)
    contract_array.append({"contractName": full_contract_name, "txid": txid.decode('utf-8').strip('"')})
    nonce += 1

meta_data['contracts'] = contract_array
print(meta_data)

with open(f'./contract-records/{versioning[1:]}.json', 'w') as f:
    json.dump(meta_data, f)