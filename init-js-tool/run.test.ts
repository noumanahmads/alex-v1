import {
  get_some_token,
  mint_some_tokens,
  set_faucet_amounts,
} from './runSteps/mint-get-token';
import { setStxAmount } from './faucet';
import {
  DEPLOYER_ACCOUNT_ADDRESS,
  STACKS_API_URL,
  USER_ACCOUNT_ADDRESS,
} from './constants';
import { mint_ft } from './vault';
import { launchAddToPosition, launchCreate } from './pools-launch';
import { genesis_transfer, getDeployerPK, network } from './wallet';
import { deployAllContracts, deployContract } from '../features/deployContractsUtils';
import { broadcastTransaction, makeContractDeploy } from '@stacks/transactions';
import fs from 'fs';
import path from 'path';

async function getCurrentBlock() {
  return fetch(`${STACKS_API_URL()}/v2/info`)
    .then(r => r.json())
    .then(r => r['burn_block_height']);
}

describe('run scripts', () => {
  test('setup launchpad', async () => {
    await genesis_transfer();

    await deployAllContracts(
      'mint-fixed,faucet,alex-launchpad,lottery-t-alex,token-',
    );

    await set_faucet_amounts();
    // we need more STX
    await setStxAmount(100000e8);
    await mint_some_tokens(DEPLOYER_ACCOUNT_ADDRESS());
    await mint_some_tokens(USER_ACCOUNT_ADDRESS());
    await get_some_token(USER_ACCOUNT_ADDRESS());

    await mint_ft('token-t-alex', 100000e8, DEPLOYER_ACCOUNT_ADDRESS());
    await mint_ft('lottery-t-alex', 10000e8, USER_ACCOUNT_ADDRESS());

    const currentBlock = await getCurrentBlock();
    await launchCreate(
      'token-t-alex',
      'lottery-t-alex',
      DEPLOYER_ACCOUNT_ADDRESS(),
      100,
      25e8,
      currentBlock + 60,
      currentBlock + 200,
      43000,
      100,
    );
    await launchAddToPosition('token-t-alex', 1000);
  });

  test('set secondary wallet', async () => {
    const adx = 'ST10YE5DNRXVNY7SB5Z8B8X3Q1WC2Q7X5P7C8BBQ4';
    await mint_some_tokens(adx);
    await get_some_token(adx);
    await mint_ft('lottery-t-alex', 10000e8, adx);
  });

  test('deploy variant', async () => {
    const contractName = 'alex-launchpad-v2';
    await deployContract(contractName, 'contracts/pool/alex-launchpad.clar');
    const currentBlock = await getCurrentBlock();
    await launchCreate(
      'token-t-alex',
      'lottery-t-alex',
      DEPLOYER_ACCOUNT_ADDRESS(),
      100,
      25e8,
      currentBlock + 20,
      currentBlock + 100,
      43000,
      100,
      contractName,
    );
    await launchAddToPosition('token-t-alex', 100, contractName);
  });
});