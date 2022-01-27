
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

const ONE_16 = 10000000000000000;
const ONE_8 = 100000000;

Clarinet.test({
    name: "math-big-uint: greater than equal to",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        
        let deployer = accounts.get("deployer")!;
        let call = chain.callReadOnlyFn("math-log-exp-biguint", "greater-than-equal-to", 
        [
            types.int(250),
            types.int(-4),
            types.int(25),
            types.int(-3)
        ], deployer.address
        );
        // call.result.expectBool(true);
        // call = chain.callReadOnlyFn("math-log-exp-biguint", "greater-than-equal-to", 
        // [
        //     types.int(10),
        //     types.int(3),
        //     types.int(20),
        //     types.int(3)
        // ], deployer.address
        // );
        // call.result.expectBool(false);

        // call = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra", 
        // [
        //     // types.int(126641655490941765),
        //     // types.int(-30),
        //     // types.int(8886110520507872),
        //     // types.int(-9)
        //     // types.int(500000000000000),
        //     types.int(5),
        //     types.int(14),
        //     types.int(7896296018268069),
        //     types.int(-2)
        // ], deployer.address
        // );

       // console.log('Nouman ', call.result);

        // call = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra", 
        // [
        //     types.int(1),
        //     types.int(-30),
        //     types.int(8886110520507872),
        //     types.int(-9)
        // ], deployer.address
        // );

        // // console.log('Nouman ', call.result);
       
    },
});

Clarinet.test({
    name: "math-big-uint: subtraction",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        //  '50000000000'
        let deployer = accounts.get("deployer")!;
        console.log("For input =10")
        let call = chain.callReadOnlyFn("math-log-exp-biguint", "subtraction-with-scientific-notation",     
        [
            '1053992245333503834',
            types.int(-18),
            types.int(100*ONE_16),
            types.int(0),
        ], deployer.address);
        console.log('Subtraction', call.result);
    },
});


Clarinet.test({
    name: "math-big-uint: ln-priv-16",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        //  '50000000000'
        let deployer = accounts.get("deployer")!;
        console.log("For input =10")
        let call = chain.callReadOnlyFn("math-log-exp-biguint", "ln-priv-16",
        [
           types.int(10),
            types.int(0),
        ], deployer.address);
        console.log('Result 16', call.result);

        call = chain.callReadOnlyFn("math-log-exp", "ln-priv-extra", 
        [
            types.int(10 * ONE_8),
        ], deployer.address);
        console.log('Result 8 ', call.result);
    //      console.log("For input =5e8")
    //     call = chain.callReadOnlyFn("math-log-exp-biguint", "ln-priv-16",
    //     [
    //         '500000000',
    //         types.int(0),
    //     ], deployer.address);
    //     console.log('Result 16', call.result);

    //     call = chain.callReadOnlyFn("math-log-exp", "ln-priv-extra", 
    //     [
    //         '50000000000000000'
    //     ], deployer.address);
    //     console.log('Result 8 ', call.result);
    //     console.log("For input =5e14")
    //     call = chain.callReadOnlyFn("math-log-exp-biguint", "ln-priv-16",
    //     [
    //         '500000000000000',
    //         types.int(0),
    //     ], deployer.address);
    //     console.log('Result 16', call.result);

    //     call = chain.callReadOnlyFn("math-log-exp", "ln-priv-extra", 
    //     [
    //         '50000000000000000000000'
    //     ], deployer.address);
    //     console.log('Result 8 ', call.result);
    },
});

// Clarinet.test({
//     name: "math-big-uint: max number",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "maximum-integer",
//             [
//                 types.uint(500*ONE_16), //19 digits
//                 types.uint(5000*ONE_16), //20 digits
//             ], deployer.address);
//         assertEquals(call.result, "u250000000000000000000000000000000000000") //39 digits MAX
//     },
// });

// Clarinet.test({
//     name: "math-big-uint: mul",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "mul",
//             [
//                 types.uint(5),
//                 types.uint(5),
//             ], deployer.address);
//         call.result.expectUint(25*ONE_16)
//     },
// });


// Clarinet.test({
//     name: "math-big-uint: div",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "div",
//             [
//                 types.uint(5),
//                 types.uint(5)
//             ], deployer.address);
//         call.result.expectUint(1*ONE_16)

//         call = chain.callReadOnlyFn("math-big-uint", "div",
//             [
//                 types.uint(25123124213),
//                 types.uint(4125312513461)
//             ], deployer.address);
//         call.result.expectUint(60899929716894)
//     },
// });


// Clarinet.test({
//     name: "math-big-uint: mul-with-scientific-notation",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(25), 
//                 types.int(-1),
//                 // this number becomes 25*10^-1=2.5
//                 types.uint(4),
//                 types.int(0),
//                 // this number becomes 4*10^0=4
//             ], deployer.address);
//         let position: any = call.result.expectTuple()
//         position['result'].expectUint(100)
//         position['exponent'].expectInt(-1)
//         // the answer is 100*10^-1 = 10

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(0),
//                 types.uint(1122334455667788),
//                 types.int(0),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1259634630379109987517020812944")
//         position['exponent'].expectInt(0)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(0),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1259634630379109987517020812944")
//         position['exponent'].expectInt(-16)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(-16),
//                 types.uint(1122334455667788),
//                 types.int(0),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1259634630379109987517020812944")
//         position['exponent'].expectInt(-16)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(-16),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1259634630379109987517020812944")
//         position['exponent'].expectInt(-32)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(16),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1259634630379109987517020812944")
//         position['exponent'].expectInt(0)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(500000), 
//                 types.int(0),
//                 types.uint(5),
//                 types.int(-1),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u2500000")
//         position['exponent'].expectInt(-1)

//         call = chain.callReadOnlyFn("math-big-uint", "mul-with-scientific-notation",
//             [
//                 types.uint(6000000), 
//                 types.int(0),
//                 types.uint(67),
//                 types.int(-2),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u402000000")
//         position['exponent'].expectInt(-2)

//     },
// });

// Clarinet.test({
//     name: "math-big-uint: div-with-scientific-notation",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(25),
//                 types.int(-1),
//                 // this number becomes 25*10^-1=2.5
//                 types.uint(4),
//                 types.int(0),
//                 // this number becomes 4*10^0=4
//             ], deployer.address);
//         let position: any = call.result.expectTuple()
//         position['result'].expectUint(6.25*ONE_16)
//         position['exponent'].expectInt(-17)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//         [
//             types.uint(1122334455667788), 
//             types.int(0),
//             types.uint(1122334455667788),
//             types.int(0),
//         ], deployer.address);
//         position = call.result.expectTuple()
//         position['result'].expectUint(1*ONE_16)
//         position['exponent'].expectInt(-16)
        
//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(0),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         position['result'].expectUint(1*ONE_16)
//         position['exponent'].expectInt(0)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(-16),
//                 types.uint(1122334455667788),
//                 types.int(0),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         position['result'].expectUint(1*ONE_16)
//         position['exponent'].expectInt(-32)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(-16),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         position['result'].expectUint(1*ONE_16)
//         position['exponent'].expectInt(-16)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(1122334455667788), 
//                 types.int(16),
//                 types.uint(1122334455667788),
//                 types.int(-16),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         position['result'].expectUint(1*ONE_16)
//         position['exponent'].expectInt(16)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(500000), 
//                 types.int(0),
//                 types.uint(5),
//                 types.int(-1),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u1000000000000000000000") // 1,000,000 * ONE_16
//         position['exponent'].expectInt(-15)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(6000000), 
//                 types.int(0),
//                 types.uint(67),
//                 types.int(-2),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u895522388059701492537") //8,955,223.88059701492537
//         position['exponent'].expectInt(-14)

//         call = chain.callReadOnlyFn("math-big-uint", "div-with-scientific-notation",
//             [
//                 types.uint(8877665544332211), 
//                 types.int(0),
//                 types.uint(1122334),
//                 types.int(0),
//             ], deployer.address);
//         position = call.result.expectTuple()
//         assertEquals(position['result'], "u79100032114613038542893648") //7,910,003,211.38542893648
//         position['exponent'].expectInt(-16)

//     },
// });

// Clarinet.test({
//     name: "math-big-uint: natural log",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "ln",
//             [
//                 types.int(10*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "23025850929940452")

//         call = chain.callReadOnlyFn("math-big-uint", "ln",
//             [
//                 types.int(50000*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "108197782844102828")

//         call = chain.callReadOnlyFn("math-big-uint", "ln",
//             [
//                 types.int(0.5*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "-6931471805599448")
//     }
// })

// Clarinet.test({
//     name: "math-big-uint: exponent",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "exp",
//             [
//                 types.int(10*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "220264657948067164354")

//         call = chain.callReadOnlyFn("math-big-uint", "exp",
//             [
//                 types.int(1*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "27182818284590452")

//         call = chain.callReadOnlyFn("math-big-uint", "exp",
//             [
//                 types.int(5*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "1484131591025766015")
//     }
// })

// Clarinet.test({
//     name: "math-big-uint: power",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;

//         let call = chain.callReadOnlyFn("math-big-uint", "power",
//             [
//                 types.uint(2*ONE_16),
//                 types.uint(10*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "u10239999999999944845")

//         call = chain.callReadOnlyFn("math-big-uint", "power",
//             [
//                 types.uint(2*ONE_16),
//                 types.uint(5*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "u319999999999999061")

//         call = chain.callReadOnlyFn("math-big-uint", "power",
//             [
//                 types.uint(5*ONE_16),
//                 types.uint(5*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "u31249999999999902485")

//         call = chain.callReadOnlyFn("math-big-uint", "power",
//             [
//                 types.uint(5*ONE_16),
//                 types.uint(0.5*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "u22360679774997883")

//         call = chain.callReadOnlyFn("math-big-uint", "power",
//             [
//                 types.uint(5*ONE_16),
//                 types.uint(0.125*ONE_16),
//             ], deployer.address);
//         assertEquals(call.result, "u12228445449938512")
//     }
// })

// Clarinet.test({
//     name: "math-big-uint: div-update",
//     async fn(chain: Chain, accounts: Map<string, Account>) {
        
//         let deployer = accounts.get("deployer")!;
//         let call2 = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra-minahil", 
//         [
//             '63320827745470882754220',
//             types.int(-22),
//             types.int(2718281828459045),
//             types.int(-15)
//         ], deployer.address
//         );
//         console.log('Div Minahil', call2.result);
//         call2 = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra-minahil", 
//         [
//             types.int(10),
//             types.int(0),
//             types.int(3),
//             types.int(0)
//         ], deployer.address
//         );
//         console.log('Div Minahil2', call2.result);

//         call2 = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra-minahil", 
//         [
//             types.int(100),
//             types.int(0),
//             types.int(4),
//             types.int(0)
//         ], deployer.address
//         );
//         console.log('Div Minahil3', call2.result);

//         let call1 = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra",
//             [
//                 types.int(10),
//                 types.int(0),
//                 types.int(7389056098930650),
//                 types.int(-15)
//             ], deployer.address);
//         console.log("Div extra result", call1.result);

//         let call = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra",
//             [
//                 types.int(50000),
//                 types.int(0),
//                 types.int(2),
//                 types.int(0)
//             ], deployer.address);
//         assertEquals(call.result, "{result: {a: 250000000000000000000, exp: -16}}")

//         call = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra",
//             [
//                 types.int(50000),
//                 types.int(0),
//                 types.int(7896296018268069),
//                 types.int(-2)
//             ], deployer.address);
//         console.log('result error ', call.result);
//        assertEquals(call.result, "{result: {a: 633208277454708827542, exp: -30}}")

//         call = chain.callReadOnlyFn("math-log-exp-biguint", "div-update-extra",
//             [
//                 types.int(ONE_16),
//                 types.int(0),
//                 types.int(2718281828459045),
//                 types.int(-15)
//             ], deployer.address);
//             console.log('result error 2 ', call.result);
//         assertEquals(call.result, "{result: {a: 36787944117144235, exp: -1}}")
//     }
// })