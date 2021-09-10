require('dotenv').config();
const { initCoinPrice, setOpenOracle,test } = require('./oracles').default;
const { createFWP, createCRP, createYTP, swapYForX } = require('./pools');
async function run() {
  // const {usdc, btc} = await initCoinPrice()
  // Need to call it one by one, or you'll receive 'ConflictingNonceInMempool' Error
  // await setOpenOracle('WBTC','CoinGecko', btc);
  // await setOpenOracle('USDA','CoinGecko', usdc);
  // await createFWP()
//   await createYTP(
//     'yield-wbtc-59760',
//     'token-wbtc',
//     'ytp-yield-wbtc-59760-wbtc'
//   );
//   await createYTP(
//     'yield-wbtc-79760',
//     'token-wbtc',
//     'ytp-yield-wbtc-79760-wbtc'
//   );
//   await createCRP('yield-wbtc-59760', 'key-wbtc-59760-usda');
//   await createCRP('yield-wbtc-79760', 'key-wbtc-79760-usda');
//   await swapYForX('yield-wbtc-59760', 'token-wbtc');
//   await swapYForX('yield-wbtc-79760', 'token-wbtc');
}
run();
