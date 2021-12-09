import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { ALEXLaunchpad, ErrCode } from './models/alex-tests-launchpad.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';
import { 
    TestALEXLottery,
    TestALEXToken,
    WSTXToken
  } from './models/alex-tests-tokens.ts';

const ONE_8 = 100000000
const ACTIVATION_THRESHOLD = 1
const REGISTRATION_START = 50
const REGISTRATION_END = 100
const CLAIM_END = 150
const TICKETS_NUM = 1
const OWNER = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE"
const TOKEN_TRAIT_ADDRESS = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.token-t-alex"
const TICKET_TRAIT_ADDRESS = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE.lottery-t-alex" 
const FEE_TO_ADDRESS = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE"

Clarinet.test({
    name: "ALP: Testing helper functions",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let result = ALPTest.setOwner(deployer, OWNER);
        result.expectOk().expectBool(true);

        let result2 = ALPTest.getOwner();        
        assertEquals(result2.result, "(ok ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)");
    }
})

Clarinet.test({
    name: "ALP: pool creation, adding values and reducing values",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // if REGISTRATION_START > REGISTRATION_END, contract should throw error 'INVALID_REGISTRATION_PERIOD'
        // swapping these params for testing
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_END, REGISTRATION_START, CLAIM_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_REGISTRATION_PERIOD);

        // if CLAIM_END < REGISTRATION_END, contract should throw error 'INVALID_CLAIM_PERIOD'
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  REGISTRATION_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_CLAIM_PERIOD);

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  CLAIM_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectOk().expectBool(true);

        // Wallet-1 i.e. not an owner trying to create pool, will get authorization error
        result = ALPTest.createPool(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END, CLAIM_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_UNAUTHORIZED);

        // getRegistrationStart should return REGISTRATION_START value
        result = ALPTest.getRegistrationStart(TOKEN_TRAIT_ADDRESS).result;
        result.expectOk().expectUint(REGISTRATION_START);

        // getRegistrationStart should not accept invalid token
        result = ALPTest.getRegistrationStart(TICKET_TRAIT_ADDRESS).result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TOKEN);

        // we have 1 set as activation threshold, so response should be u1
        result = ALPTest.getActivationThreshold(TOKEN_TRAIT_ADDRESS).result;
        result.expectOk().expectUint(ACTIVATION_THRESHOLD);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        // Check with un-authorized user
        result = ALPTest.addToPosition(wallet_1, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_UNAUTHORIZED);

        // Check with 0 tickets. ERR_INVALID_TICKETS should be returned
        result = ALPTest.addToPosition(deployer, TOKEN_TRAIT_ADDRESS, 0).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TICKET)

        // check with more number of tickets than owned by user
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM * ONE_8).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_TRANSFER_FAILED);

        // Check with authorized user, (OK true) should be returned
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);
        
        // check with wrong address, invalid token error will be thrown
        result = ALPTest.addToPosition (deployer, TICKET_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TOKEN);
    }
})

Clarinet.test({
    name: "ALP: User Registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END, CLAIM_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectOk().expectBool(true);
 
        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        // Contract should not register any address until REGISTRATION_START block has reached
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100);
        result.expectErr().expectUint(ErrCode.ERR_REGISTRATION_NOT_STARTED);

        // Mine block until REGISTRATION_START to start the registration process
        chain.mineEmptyBlockUntil(REGISTRATION_START);

        // Register with the Token and Ticket with which the pool is created
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100);
        result.expectOk().expectBool(true);

        // contract should not register the same address again
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 10);
        result.expectErr().expectUint(ErrCode.ERR_USER_ALREADY_REGISTERED);

        // Attempt to register with more tickets than owned, throws ERR-TICKET-TRANSFER-FAILED
        result = ALPTest.register(wallet_2, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 111);
        result.expectErr().expectUint(ErrCode.ERR_TICKET_TRANSFER_FAILED);

        // Try registering with wrong ticket-token combination
        result = ALPTest.register(wallet_2, TICKET_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 10);
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TOKEN);
        result = ALPTest.register(wallet_2, TOKEN_TRAIT_ADDRESS, TOKEN_TRAIT_ADDRESS, 10);
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TICKET)

        // Below test should returned the number of successfully registered users i.e. 1
        result = ALPTest.getRegisteredUsersNonce(TOKEN_TRAIT_ADDRESS).result;
        result.expectOk().expectUint(1)

        chain.mineEmptyBlockUntil(REGISTRATION_END + 1);

        // Contract should not register any address if REGISTRATION_END block has reached
        result = ALPTest.register(wallet_2, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 1)
        result.expectErr().expectUint(ErrCode.ERR_REGISTRATION_ENDED);
    }
})

Clarinet.test({
    name: "ALP: Claim tokens",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  CLAIM_END, ACTIVATION_THRESHOLD).receipts[0].result;
        result.expectOk().expectBool(true);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        // Claim at this point should return ERR-REGISTRATION-NOT-ENDED
        result = ALPTest.claim (deployer, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_REGISTRATION_NOT_ENDED);

        // Register with the Token and Ticket with which the pool is created
        chain.mineEmptyBlockUntil(REGISTRATION_START)
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100)
        result.expectOk().expectBool(true);
        
        chain.mineEmptyBlockUntil(REGISTRATION_END + 1)
        
        // Wrong ticket param should throw ERR_INVALID_TICKET
        result = ALPTest.claim (wallet_1, TOKEN_TRAIT_ADDRESS, TOKEN_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TICKET);

        // Wrong token param should throw ERR_INVALID_TOKEN
        result = ALPTest.claim (wallet_1, TICKET_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TOKEN);

        // Test with accurate combination of ticket token trait should pass
        result = ALPTest.claim (wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectOk().expectBool(true);

        // Again claiming against same token-ticket combination should now throw LISTING_FINISHED error
        result = ALPTest.claim (wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_LISTING_FINISHED);
    }
})


Clarinet.test({
    name: "ALP: Registration Started before Add to Position",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  CLAIM_END, ACTIVATION_THRESHOLD);
        result.receipts[0].result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(REGISTRATION_START)
        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_REGISTRATION_STARTED);
    }
})

Clarinet.test({
    name: "ALP: Claim Ended Error",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  CLAIM_END, ACTIVATION_THRESHOLD);
        result.receipts[0].result.expectOk().expectBool(true);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(REGISTRATION_START);

        // Register with the Token and Ticket with which the pool is created
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100);
        result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(CLAIM_END + 1)
        // Try calling claim after CLAIM_END period. It should throw error CLAIM_END
        result = ALPTest.claim (wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_CLAIM_ENDED);
    }
})

Clarinet.test({
    name: "ALP: Test Token Details",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END,  CLAIM_END, ACTIVATION_THRESHOLD);
        result.receipts[0].result.expectOk().expectBool(true);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(REGISTRATION_START)

        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100);
        result.expectOk().expectBool(true);

        result = ALPTest.getTokenDetails(TOKEN_TRAIT_ADDRESS).result;
        result = result.expectSome().expectTuple();
        result['activation-threshold'].expectUint(1)
        result['amount-per-ticket'].expectUint(100)
        result['last-random'].expectUint(0)
        result['registration-end'].expectUint(REGISTRATION_END)
        result['registration-start'].expectUint(REGISTRATION_START)
        result['tickets-won'].expectUint(0)
        result['total-subscribed'].expectUint(100)
        result['total-tickets'].expectUint(1)
        result['users-nonce'].expectUint(1)
        result['wstx-per-ticket-in-fixed'].expectUint(30000000)
        assertEquals(result['fee-to-address'], FEE_TO_ADDRESS);
        assertEquals(result['ticket'], TICKET_TRAIT_ADDRESS)
    }
})

Clarinet.test({
    name: "ALP: Test Subscriber at Token Details",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END, CLAIM_END, ACTIVATION_THRESHOLD);
        result.receipts[0].result.expectOk().expectBool(true);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(REGISTRATION_START)
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100)
        result.expectOk().expectBool(true);

        // subscriber at token - stored values
        result = ALPTest.getSubscriberAtTokenOrDefault(TOKEN_TRAIT_ADDRESS, 1).result;
        result = result.expectTuple();
        result['ticket-balance'].expectUint(100)
        result['tickets-lost'].expectUint(0)
        result['tickets-won'].expectUint(0)
        result['value-high'].expectUint(100)
        result['value-low'].expectUint(1)
        result['wstx-locked-in-fixed'].expectUint(3000000000)

        // subscriber at token should return default values with unavailble user-id
        result = ALPTest.getSubscriberAtTokenOrDefault(TOKEN_TRAIT_ADDRESS, 2).result;
        result = result.expectTuple();
        result['ticket-balance'].expectUint(0)
        result['tickets-lost'].expectUint(0)
        result['tickets-won'].expectUint(0)
        result['value-high'].expectUint(0)
        result['value-low'].expectUint(0)
        result['wstx-locked-in-fixed'].expectUint(0)
    }
})

Clarinet.test({
    name: "ALP: Test Refund",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get("deployer")!;
        let wallet_1 = accounts.get("wallet_1")!;
        let wallet_2 = accounts.get("wallet_2")!;
        let ALPTest = new ALEXLaunchpad(chain, deployer);

        let wstxToken = new WSTXToken(chain, deployer);
        let lottery = new TestALEXLottery(chain, deployer);
        let talexToken = new TestALEXToken(chain, deployer);
        
        let result:any = talexToken.mintFixed(deployer, deployer.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_1, wallet_1.address, 10000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_1.address, 100 * ONE_8);
        result.expectOk();
        result = wstxToken.mintFixed(wallet_2, wallet_2.address, 1000 * ONE_8);
        result.expectOk();
        result = lottery.mintFixed(deployer, wallet_2.address, 10 * ONE_8);
        result.expectOk();        

        // Deployer creating a pool, FEE_TO_ADDRESS will be the one that's getting added in the pool
        result = ALPTest.createPool(deployer, TOKEN_TRAIT_ADDRESS , TICKET_TRAIT_ADDRESS, FEE_TO_ADDRESS, 100, 3e7, REGISTRATION_START, REGISTRATION_END, CLAIM_END, ACTIVATION_THRESHOLD);
        result.receipts[0].result.expectOk().expectBool(true);

        // Add to position expects the same TOKEN_TRAIT_ADDRESSN that pool was created with
        result = ALPTest.addToPosition (deployer, TOKEN_TRAIT_ADDRESS, TICKETS_NUM).receipts[0].result;
        result.expectOk().expectBool(true);

        chain.mineEmptyBlockUntil(REGISTRATION_START)
        result = ALPTest.register(wallet_1, TOKEN_TRAIT_ADDRESS, TICKET_TRAIT_ADDRESS, 100)
        result.expectOk().expectBool(true);

        result = ALPTest.refund(wallet_1, TICKET_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_INVALID_TOKEN)

        result = ALPTest.refund(deployer, TOKEN_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_USER_ID_NOT_FOUND)

        result = ALPTest.refund(wallet_1, TOKEN_TRAIT_ADDRESS).receipts[0].result;
        result.expectErr().expectUint(ErrCode.ERR_LISTING_ACTIVATED)
    }
})