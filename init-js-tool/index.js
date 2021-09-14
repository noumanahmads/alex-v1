require('dotenv').config();
const { initCoinPrice, setOpenOracle } = require('./oracles').default;
const { createFWP, createCRP, createYTP, borrow } = require('./pools');
async function run() {
  // const { usdc, btc } = await initCoinPrice();
  //Need to call it one by one, or you'll receive 'ConflictingNonceInMempool' Error
  // await setOpenOracle('WBTC','nothing', btc);
  // await setOpenOracle('USDA','nothing', usdc);
  // await createFWP()
  // await createYTP(
  //   'yield-wbtc-59760',
  //   'token-wbtc',
  //   'ytp-yield-wbtc-59760-wbtc',
  //   'multisig-ytp-yield-wbtc-59760-wbtc'
  // );

  // await createYTP(
  //   'yield-wbtc-79760',
  //   'token-wbtc',
  //   'ytp-yield-wbtc-79760-wbtc',
  //   'multisig-ytp-yield-wbtc-79760-wbtc'
  // );
  // await createCRP(
  //   'yield-wbtc-59760',
  //   'key-wbtc-59760-usda',
  //   'multisig-ytp-yield-wbtc-59760-wbtc'
  // );
  // await borrow('yield-wbtc-59760', 'token-wbtc', 2);
}
run();
