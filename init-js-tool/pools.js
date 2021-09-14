const { getPK, network } = require('./wallet');
const {
  makeContractCall,
  AnchorMode,
  PostConditionMode,
  uintCV,
  contractPrincipalCV,
  broadcastTransaction,
} = require('@stacks/transactions');

const createFWP = async () => {
  const privateKey = await getPK();
  const txOptions = {
    contractAddress: process.env.ACCOUNT_ADDRESS,
    contractName: 'fixed-weight-pool',
    functionName: 'create-pool',
    functionArgs: [
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, 'token-wbtc'),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, 'token-usda'),
      uintCV(5 * 1e7),
      uintCV(5 * 1e7),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, 'fwp-wbtc-usda-50-50'),
      contractPrincipalCV(
        process.env.ACCOUNT_ADDRESS,
        'multisig-fwp-wbtc-usda-50-50'
      ),
      uintCV(100 * 1e8),
      uintCV(5000 * 100 * 1e8),
    ],
    senderKey: privateKey,
    validateWithAbi: true,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
  try {
    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(broadcastResponse);
  } catch (error) {
    console.log(error);
  }
};
const createCRP = async (yiedToken, keyToken, multisig) => {
  const privateKey = await getPK();
  const txOptions = {
    contractAddress: process.env.ACCOUNT_ADDRESS,
    contractName: 'collateral-rebalancing-pool',
    functionName: 'create-pool',
    functionArgs: [
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, 'token-wbtc'),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, 'token-usda'),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, yiedToken),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, keyToken),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, multisig),
      uintCV(0.8 * 1e8),
      uintCV(0.95 * 1e8),
      uintCV(0.8 * 1e8),
      uintCV(0),
      uintCV(50000 * 1e8),
    ],
    senderKey: privateKey,
    validateWithAbi: true,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
  try {
    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(broadcastResponse);
  } catch (error) {
    console.log(error);
  }
};
const createYTP = async (yiedToken, token, poolToken, multisig) => {
  const privateKey = await getPK();
  const txOptions = {
    contractAddress: process.env.ACCOUNT_ADDRESS,
    contractName: 'yield-token-pool',
    functionName: 'create-pool',
    functionArgs: [
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, yiedToken),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, token),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, poolToken),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, multisig),
      uintCV(10 * 1e8),
      uintCV(10 * 1e8),
    ],
    senderKey: privateKey,
    validateWithAbi: true,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
  try {
    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(broadcastResponse);
  } catch (error) {
    console.log(error);
  }
};
const borrow = async (yiedToken, token, dy)=>{
    const privateKey = await getPK();
  const txOptions = {
    contractAddress: process.env.ACCOUNT_ADDRESS,
    contractName: 'yield-token-pool',
    functionName: 'swap-y-for-x',
    functionArgs: [
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, yiedToken),
      contractPrincipalCV(process.env.ACCOUNT_ADDRESS, token),
      uintCV(dy * 1e8),
    ],
    senderKey: privateKey,
    validateWithAbi: true,
    network,
    anchorMode: AnchorMode.Any,
    postConditionMode: PostConditionMode.Allow,
  };
  try {
    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    console.log(broadcastResponse);
  } catch (error) {
    console.log(error);
  }
}
const swapYForX = async (yieldToken, token)=>{
    const privateKey = await getPK();
    const txOptions = {
        contractAddress: process.env.ACCOUNT_ADDRESS,
        contractName: 'yield-token-pool',
        functionName: 'swap-y-for-x',
        functionArgs: [
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS, yieldToken),
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS, token),
            uintCV(2*1e8),
        ],
        senderKey: privateKey,
        validateWithAbi: true,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
    };
}
exports.createFWP = createFWP;
exports.createCRP = createCRP;
exports.createYTP = createYTP;
exports.borrow = borrow;
