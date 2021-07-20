import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from 'https://deno.land/x/clarinet@v0.14.2-develop.1/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

const gAlexTokenAddress =
  'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.token-alex';
const usdaTokenAddress = 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.token-usda';
const testAccount = "ST36TRBFNKPB1TQT13S6PMPFFW32TD7A3NVBXNAW2"
Clarinet.test({
  name: 'Ensure that <...>',
  async fn(chain: Chain, accounts: Map<string, Account>) {
    let deployer = accounts.get('deployer')!;
    let block = chain.mineBlock([
      Tx.contractCall(
        'flash-loan-v1',
        'execute',
        [
          types.principal(usdaTokenAddress),
          types.principal(usdaTokenAddress),
          types.principal(usdaTokenAddress),
          types.uint(100), 
          types.uint(100),
          types.uint(100),
        ],
        deployer.address
      ),
    //   Tx.contractCall(
    //     'flash-loan-v1',
    //     'get-token-name',
    //     [
    //       types.principal(usdaTokenAddress),
    //       types.uint(100),
    //       types.principal(testAccount)
    //     ],
    //     deployer.address
    //   ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    console.log(block.receipts[1].result);
  },
});
