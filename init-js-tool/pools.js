const {
    getPK, network
  } = require('./wallet');
const {
    makeContractCall,
    AnchorMode,
    PostConditionMode,
    uintCV,
    contractPrincipalCV,
    broadcastTransaction
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
            uintCV(5*1e7),
            uintCV(5*1e7),
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS,'fwp-wbtc-usda'),
            uintCV(10000*1e8),
            uintCV(500000000*1e8),
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
const createCRP = async (yiedToken, keyToken) => {
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
            uintCV(100000*1e8),
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
const createYTP = async (yiedToken, token, poolToken) => {
    const privateKey = await getPK();
    const txOptions = {
        contractAddress: process.env.ACCOUNT_ADDRESS,
        contractName: 'yield-token-pool',
        functionName: 'create-pool',
        functionArgs: [
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS, yiedToken),
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS, token),
            contractPrincipalCV(process.env.ACCOUNT_ADDRESS, poolToken),
            uintCV(100*1e8),
            uintCV(100*1e8),
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
exports.swapYForX = swapYForX;
