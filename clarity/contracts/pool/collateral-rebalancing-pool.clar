(impl-trait .trait-ownable.ownable-trait)
(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait sft-trait .trait-semi-fungible.semi-fungible-trait)

(use-trait multisig-trait .trait-multisig-vote.multisig-vote-sft-trait)

;; collateral-rebalancing-pool
;;

;; constants
;;
(define-constant ONE_8 u100000000) ;; 8 decimal places

(define-constant ERR-INVALID-POOL (err u2001))
(define-constant ERR-INVALID-LIQUIDITY (err u2003))
(define-constant ERR-TRANSFER-FAILED (err u3000))
(define-constant ERR-POOL-ALREADY-EXISTS (err u2000))
(define-constant ERR-TOO-MANY-POOLS (err u2004))
(define-constant ERR-PERCENT-GREATER-THAN-ONE (err u5000))
(define-constant ERR-WEIGHTED-EQUATION-CALL (err u2009))
(define-constant ERR-GET-WEIGHT-FAIL (err u2012))
(define-constant ERR-EXPIRY (err u2017))
(define-constant ERR-GET-BALANCE-FIXED-FAIL (err u6001))
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-LTV-GREATER-THAN-ONE (err u2019))
(define-constant ERR-EXCEEDS-MAX-SLIPPAGE (err u2020))
(define-constant ERR-INVALID-TOKEN (err u2026))
(define-constant ERR-POOL-AT-CAPACITY (err u2027))

(define-constant a1 u27839300)
(define-constant a2 u23038900)
(define-constant a3 u97200)
(define-constant a4 u7810800)

(define-data-var contract-owner principal tx-sender)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner owner))
  )
)

;; data maps and vars
;;
(define-map pools-map
  { pool-id: uint }
  {
    token-x: principal, ;; collateral
    token-y: principal, ;; token
    expiry: uint    
  }
)

(define-map pools-data-map
  {
    token-x: principal,
    token-y: principal,
    expiry: uint
  }
  {
    yield-supply: uint,
    key-supply: uint,
    balance-x: uint,
    balance-y: uint,
    fee-to-address: principal,
    yield-token: principal,
    key-token: principal,
    strike: uint,
    bs-vol: uint,
    ltv-0: uint,
    fee-rate-x: uint,
    fee-rate-y: uint,
    fee-rebate: uint,
    weight-x: uint,
    weight-y: uint,
    moving-average: uint,
    conversion-ltv: uint,
    token-to-maturity: uint
  }
)

(define-data-var pool-count uint u0)
(define-data-var pools-list (list 2000 uint) (list))

;; private functions
;;

;; Approximation of Error Function using Abramowitz and Stegun
;; https://en.wikipedia.org/wiki/Error_function#Approximation_with_elementary_functions
;; Please note erf(x) equals -erf(-x)
(define-private (erf (x uint))
    (let
        (
            (a1x (mul-down a1 x))
            (x2 (mul-down x x))
            (a2x (mul-down a2 x2))
            (x3 (mul-down x (mul-down x x)))
            (a3x (mul-down a3 x3))
            (x4 (mul-down x (mul-down x (mul-down x x))))
            (a4x (mul-down a4 x4))
            (denom (+ ONE_8 a1x))
            (denom1 (+ denom a2x))
            (denom2 (+ denom1 a3x))
            (denom3 (+ denom2 a4x))
            (denom4 (mul-down denom3 (mul-down denom3 (mul-down denom3 denom3))))
            (base (div-down ONE_8 denom4))
        )
        (if (<= ONE_8 base) u0 (- ONE_8 base))
    )
)

;; public functions
;;

;; @desc get-pool-count
;; @returns uint
(define-read-only (get-pool-count)
    (var-get pool-count)
)

;; @desc get-pool-contracts
;; @param pool-id; pool-id
;; @returns (response (tuple) uint)
(define-read-only (get-pool-contracts (pool-id uint))
    (ok (unwrap! (map-get? pools-map {pool-id: pool-id}) ERR-INVALID-POOL))
)

;; @desc get-pools
;; @returns (optional (tuple))
(define-read-only (get-pools)
    (map get-pool-contracts (var-get pools-list))
)

;; @desc get-pool-details
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @returns (response (tuple) uint)
(define-read-only (get-pool-details (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (ok (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))
)

;; @desc get-spot
;; @desc units of token per unit of collateral
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @returns (response uint uint)
(define-read-only (get-spot (token <ft-trait>) (collateral <ft-trait>))
    (if (is-eq token collateral)
        (ok ONE_8)
        (if (is-eq (contract-of token) .token-wstx)
            (contract-call? .fixed-weight-pool get-oracle-resilient .token-wstx collateral u50000000 u50000000)
            (if (is-eq (contract-of collateral) .token-wstx)
                (ok (div-down ONE_8 (try! (contract-call? .fixed-weight-pool get-oracle-resilient .token-wstx token u50000000 u50000000))))
                (ok
                    (div-down 
                        (try! (contract-call? .fixed-weight-pool get-oracle-resilient .token-wstx collateral u50000000 u50000000))
                        (try! (contract-call? .fixed-weight-pool get-oracle-resilient .token-wstx token u50000000 u50000000))
                    )
                )   
            )
        )
    )
)

(define-read-only (get-pool-value-in-token (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (get-pool-value-in-token-with-spot token collateral expiry (try! (get-spot token collateral)))
)

;; @desc get-pool-value-in-token-with-spot
;; @desc value of pool in units of borrow token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @returns (response uint uint)
(define-private (get-pool-value-in-token-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))            
            (balance-y (get balance-y pool))
            (balance-x-in-y (div-down (get balance-x pool) spot))
        )
        (ok (+ balance-x-in-y balance-y))
    )
)

(define-read-only (get-pool-value-in-collateral (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (get-pool-value-in-collateral-with-spot token collateral expiry (try! (get-spot token collateral)))
)

;; @desc get-pool-value-in-collateral-with-spot
;; @desc value of pool in units of collateral token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @returns (response uint uint)
(define-private (get-pool-value-in-collateral-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))   
            (balance-x (get balance-x pool))
            (balance-y-in-x (mul-down (get balance-y pool) spot))
        )
        (ok (+ balance-y-in-x balance-x))
    )
)

(define-read-only (get-ltv (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (get-ltv-with-spot token collateral expiry (try! (get-spot token collateral)))
)

;; @desc get-ltv-with-spot
;; @desc value of yield-token as % of pool value (i.e. loan-to-value)
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @returns (response uint uint)
(define-private (get-ltv-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint))
    ;; (let
    ;;     (
    ;;         (pool (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))            
    ;;         (yield-supply (get yield-supply pool)) ;; in token
    ;;         (pool-value (try! (get-pool-value-in-token-with-spot token collateral expiry spot))) ;; also in token
    ;;     )
    ;;     ;; if no liquidity in the pool, return ltv-0
    ;;     (if (is-eq yield-supply u0)
    ;;         (ok (get ltv-0 pool))
    ;;         (ok (div-down yield-supply pool-value))
    ;;     )
    ;; )
    ;;(ok (unwrap! (some u100) ERR-INVALID-POOL))
    (begin (asserts! (> u2 u1) ERR-INVALID-POOL) (ok u100))
)

(define-read-only (get-weight-y (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (get-weight-y-with-spot token collateral expiry (try! (get-spot token collateral)))
)

;; @desc get-weight-y-with-spot
;; @desc delta of borrow token (risky asset) based on reference black-scholes option with expiry/strike/bs-vol
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; expiry block-height
;; @param strike; reference strike price
;; @param bs-vol; reference black-scholes vol
;; @returns (response uint uint)
(define-private (get-weight-y-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))
            (strike (get strike pool))
            (bs-vol (get bs-vol pool))
            (moving-average (get moving-average pool))
            (now (* block-height ONE_8))
        )
        (if (or (> (try! (get-ltv-with-spot token collateral expiry spot)) (get conversion-ltv pool)) (>= now expiry))
            (ok u99900000)   
            (let 
                (
                    ;; assume 15secs per block 
                    (t (div-down (- expiry now) (* u2102400 ONE_8)))
                    (t-2 (div-down (- expiry now) (get token-to-maturity pool)))

                    ;; we calculate d1 first
                    (spot-term (div-up (try! (get-spot token collateral)) strike))
                    (pow-bs-vol (div-up (mul-down bs-vol bs-vol) u200000000))
                    (vol-term (mul-up t pow-bs-vol))
                    (sqrt-t (pow-down t u50000000))
                    (sqrt-2 (pow-down u200000000 u50000000))
            
                    (denominator (mul-down bs-vol sqrt-t))
                    (numerator (+ vol-term (- (if (> spot-term ONE_8) spot-term ONE_8) (if (> spot-term ONE_8) ONE_8 spot-term))))
                    (d1 (div-up numerator denominator))
                    (erf-term (erf (div-up d1 sqrt-2)))
                    (complement (if (> spot-term ONE_8) (+ ONE_8 erf-term) (if (<= ONE_8 erf-term) u0 (- ONE_8 erf-term))))
                    (weight-t (div-up complement u200000000))
                    (weighted 
                        (+ 
                            (mul-down moving-average (get weight-y pool)) 
                            (mul-down 
                                (- ONE_8 moving-average) 
                                (if (> t-2 ONE_8) weight-t (+ (mul-down t-2 weight-t) (mul-down (- ONE_8 t-2) u99900000)))
                            )
                        )
                    )                    
                )
                ;; make sure weight-x > 0 so it works with weighted-equation
                (ok (if (> weighted u100000) weighted u100000))
            )    
        )
    )
)

;; @desc create-pool with single sided liquidity
;; @restricted contract-owner
;; @param token; borrow token
;; @param collateral; collateral token
;; @param the-yield-token; yield-token to be minted
;; @param the-key-token; key-token to be minted
;; @param multisig-vote; multisig to govern the pool being created
;; @param ltv-0; initial loan-to-value
;; @param conversion-ltv; loan-to-value at which conversion into borrow token happens
;; @param bs-vol; reference black-scholes vol to use 
;; @param moving-average; weighting smoothing factor
;; @param dx; amount of collateral token being added
;; @returns (response bool uint)
(define-public (create-pool (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (the-yield-token <sft-trait>) (the-key-token <sft-trait>) (multisig-vote <multisig-trait>) (ltv-0 uint) (conversion-ltv uint) (bs-vol uint) (moving-average uint) (token-to-maturity uint) (dx uint)) 
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! 
            (is-none (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }))
            ERR-POOL-ALREADY-EXISTS
        )            
        (let
            (
                (pool-id (+ (var-get pool-count) u1))
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                
                (now (* block-height ONE_8))
                ;; assume 10mins per block
                (t (div-down (- expiry now) (* u52560 ONE_8)))
               
                ;; we calculate d1 first
                ;; because we support 'at-the-money' only, we can simplify formula
                (sqrt-t (pow-down t u50000000))
                (sqrt-2 (pow-down u200000000 u50000000))
                (pow-bs-vol (div-up (mul-down bs-vol bs-vol) u200000000))
                (numerator (mul-up t pow-bs-vol))
                (denominator (mul-down bs-vol sqrt-t))        
                (d1 (div-up numerator denominator))
                (erf-term (erf (div-up d1 sqrt-2)))
                (complement (if (<= ONE_8 erf-term) u0 (- ONE_8 erf-term)))
                (weighted (div-up complement u200000000))                
                (weight-y (if (> weighted u100000) weighted u100000))

                (weight-x (- ONE_8 weight-y))

                (pool-data {
                    yield-supply: u0,
                    key-supply: u0,
                    balance-x: u0,
                    balance-y: u0,
                    fee-to-address: (contract-of multisig-vote),
                    yield-token: (contract-of the-yield-token),
                    key-token: (contract-of the-key-token),
                    strike: (try! (get-spot token collateral)),
                    bs-vol: bs-vol,
                    fee-rate-x: u0,
                    fee-rate-y: u0,
                    fee-rebate: u0,
                    ltv-0: ltv-0,
                    weight-x: weight-x,
                    weight-y: weight-y,
                    moving-average: moving-average,
                    conversion-ltv: conversion-ltv,
                    token-to-maturity: token-to-maturity
                })
            )
            (map-set pools-map { pool-id: pool-id } { token-x: token-x, token-y: token-y, expiry: expiry })
            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-data)
        
            (var-set pools-list (unwrap! (as-max-len? (append (var-get pools-list) pool-id) u2000) ERR-TOO-MANY-POOLS))
            (var-set pool-count pool-id)
            (try! (add-to-position token collateral expiry the-yield-token the-key-token dx))
            (print { object: "pool", action: "created", data: pool-data })
            (ok true)
        )
    )
)

;; @desc mint yield-token and key-token, swap minted yield-token with token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param the-yield-token; yield-token to be minted
;; @param the-key-token; key-token to be minted
;; @param dx; amount of collateral added
;; @post collateral; sender transfer exactly dx to alex-vault
;; @post yield-token; sender transfers > 0 to alex-vault
;; @post token; alex-vault transfers >0 to sender
;; @returns (response (tuple uint uint) uint)
(define-public (add-to-position-and-switch (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (the-yield-token <sft-trait>) (the-key-token <sft-trait>) (dx uint))
    (let
        (
            (minted-yield-token (get yield-token (try! (add-to-position token collateral expiry the-yield-token the-key-token dx))))
        )
        (contract-call? .yield-token-pool swap-y-for-x expiry the-yield-token token minted-yield-token none)
    )
)

;; @desc mint yield-token and key-token, with single-sided liquidity
;; @param token; borrow token
;; @param collateral; collateral token
;; @param the-yield-token; yield-token to be minted
;; @param the-key-token; key-token to be minted
;; @param dx; amount of collateral added
;; @post collateral; sender transfer exactly dx to alex-vault
;; @returns (response (tuple uint uint) uint)
(define-public (add-to-position (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (the-yield-token <sft-trait>) (the-key-token <sft-trait>) (dx uint))    
    (let
        (   
            (token-x (contract-of collateral))
            (token-y (contract-of token))
            (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
            (spot (try! (get-spot token collateral)))
        )
        (asserts! (> dx u0) ERR-INVALID-LIQUIDITY)
        ;; mint is possible only if ltv < 1
        (asserts! (>= (get conversion-ltv pool) (try! (get-ltv-with-spot token collateral expiry spot))) ERR-LTV-GREATER-THAN-ONE)
        (asserts! (and (is-eq (get yield-token pool) (contract-of the-yield-token)) (is-eq (get key-token pool) (contract-of the-key-token))) ERR-INVALID-TOKEN)
        (let
            (
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))
                (yield-supply (get yield-supply pool))   
                (key-supply (get key-supply pool))
                (weight-x (get weight-x pool))

                (new-supply (try! (get-token-given-position-with-spot token collateral expiry spot dx)))
                (yield-new-supply (get yield-token new-supply))
                (key-new-supply (get key-token new-supply))

                (dx-weighted (mul-down weight-x dx))
                (dx-to-dy (if (<= dx dx-weighted) u0 (- dx dx-weighted)))

                (dy-weighted 
                    (if (is-eq token-x token-y)
                        dx-to-dy
                        (if (is-eq token-x .token-wstx)
                            (get dy (try! (contract-call? .fixed-weight-pool swap-wstx-for-y token u50000000 dx-to-dy none)))
                            (if (is-eq token-y .token-wstx)
                                (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-wstx collateral u50000000 dx-to-dy none)))
                                (if (is-some (contract-call? .fixed-weight-pool get-pool-exists collateral token u50000000 u50000000))
                                    (get dy (try! (contract-call? .fixed-weight-pool swap-x-for-y collateral token u50000000 u50000000 dx-to-dy none)))
                                    (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-x token collateral u50000000 u50000000 dx-to-dy none)))
                                )
                            )
                        )
                    )
                )

                (pool-updated (merge pool {
                    yield-supply: (+ yield-new-supply yield-supply),                    
                    key-supply: (+ key-new-supply key-supply),
                    balance-x: (+ balance-x dx-weighted),
                    balance-y: (+ balance-y dy-weighted)
                }))
            ) 

            (if (is-eq token-x token-y)
                u0
                (unwrap! (contract-call? .fixed-weight-pool get-helper collateral token u50000000 u50000000 (+ dx balance-x (mul-down balance-y (try! (get-spot token collateral))))) ERR-POOL-AT-CAPACITY)
            )

            (unwrap! (contract-call? collateral transfer-fixed dx-weighted tx-sender .alex-vault none) ERR-TRANSFER-FAILED)
            (unwrap! (contract-call? token transfer-fixed dy-weighted tx-sender .alex-vault none) ERR-TRANSFER-FAILED)

            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-updated)
            ;; mint pool token and send to tx-sender
            (try! (contract-call? the-yield-token mint-fixed expiry yield-new-supply tx-sender))
            (try! (contract-call? the-key-token mint-fixed expiry key-new-supply tx-sender))
            (print { object: "pool", action: "liquidity-added", data: pool-updated })
            (ok {yield-token: yield-new-supply, key-token: key-new-supply})
        )
    )
)    

;; @desc burn yield-token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param the-yield-token; yield-token to be burnt
;; @param percent; % of yield-token held to be burnt
;; @post yield-token; alex-vault transfer exactly uints of token equal to (percent * yield-token held) to sender
;; @returns (response (tuple uint uint) uint)
(define-public (reduce-position-yield (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (the-yield-token <sft-trait>) (percent uint))
    (begin
        (asserts! (<= percent ONE_8) ERR-PERCENT-GREATER-THAN-ONE)
        ;; burn supported only at maturity
        (asserts! (> (* block-height ONE_8) expiry) ERR-EXPIRY)
        
        (let
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))
                (yield-supply (get yield-supply pool))
                (total-shares (unwrap! (contract-call? the-yield-token get-balance-fixed expiry tx-sender) ERR-GET-BALANCE-FIXED-FAIL))
                (shares (if (is-eq percent ONE_8) total-shares (mul-down total-shares percent)))   

                ;; if there are any residual collateral, convert to token
                (bal-x-to-y (if (is-eq balance-x u0) 
                                u0 
                                (if (is-eq token-x token-y)
                                    balance-x
                                    (begin
                                        (as-contract (try! (contract-call? .alex-vault transfer-ft collateral balance-x tx-sender)))
                                        ;; (as-contract (try! (contract-call? .fixed-weight-pool swap-helper collateral token u50000000 u50000000 balance-x none)))
                                        (as-contract 
                                            (if (is-eq token-x .token-wstx)
                                                (get dy (try! (contract-call? .fixed-weight-pool swap-wstx-for-y token u50000000 balance-x none)))
                                                (if (is-eq token-y .token-wstx)
                                                    (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-wstx collateral u50000000 balance-x none)))
                                                    (if (is-some (contract-call? .fixed-weight-pool get-pool-exists collateral token u50000000 u50000000))
                                                        (get dy (try! (contract-call? .fixed-weight-pool swap-x-for-y collateral token u50000000 u50000000 balance-x none)))
                                                        (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-x token collateral u50000000 u50000000 balance-x none)))
                                                    )
                                                )
                                            )                                        
                                        )
                                    )                                    
                                )
                            )
                )
                (new-bal-y (+ balance-y bal-x-to-y))
                ;; CR-02
                (bal-y-short (if (<= new-bal-y yield-supply) (- yield-supply new-bal-y) u0))                       

                (pool-updated (merge pool {
                    yield-supply: (if (<= yield-supply shares) u0 (- yield-supply shares)),
                    balance-x: u0,
                    balance-y: (if (<= (+ new-bal-y bal-y-short) shares) u0 (- (+ new-bal-y bal-y-short) shares))
                    })
                )
            )

            (asserts! (is-eq (get yield-token pool) (contract-of the-yield-token)) ERR-INVALID-TOKEN)

            ;; if any conversion happened at contract level, transfer back to vault
            (and 
                (> bal-x-to-y u0) 
                (not (is-eq token-x token-y)) 
                (as-contract (unwrap! (contract-call? token transfer-fixed bal-x-to-y tx-sender .alex-vault none) ERR-TRANSFER-FAILED))
            )

            ;; if bal-y-short > 0, then transfer the shortfall from reserve (accounting only).
            ;; TODO: what if token is exhausted but reserve have others?
            (and (> bal-y-short u0) (try! (contract-call? .alex-reserve-pool remove-from-balance token-y bal-y-short)))            
        
            ;; transfer shares of token to tx-sender, ensuring convertability of yield-token
            (try! (contract-call? .alex-vault transfer-ft token shares tx-sender))

            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-updated)
            (try! (contract-call? the-yield-token burn-fixed expiry shares tx-sender))

            (print { object: "pool", action: "liquidity-removed", data: pool-updated })
            (ok {dx: u0, dy: shares})            
        )
    )
)

;; @desc burn key-token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param the-key-token; key-token to be burnt
;; @param percent; % of key-token held to be burnt
;; @post token; alex-vault transfers > 0 token to sender
;; @post collateral; alex-vault transfers > 0 collateral to sender
;; @returns (response (tuple uint uint) uint)
(define-public (reduce-position-key (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (the-key-token <sft-trait>) (percent uint))
    (begin
        (asserts! (<= percent ONE_8) ERR-PERCENT-GREATER-THAN-ONE)
        ;; burn supported only at maturity
        (asserts! (> (* block-height ONE_8) expiry) ERR-EXPIRY)        
        (let
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))            
                (key-supply (get key-supply pool))    
                (yield-supply (get yield-supply pool))        
                (total-shares (unwrap! (contract-call? the-key-token get-balance-fixed expiry tx-sender) ERR-GET-BALANCE-FIXED-FAIL))
                (shares (if (is-eq percent ONE_8) total-shares (mul-down total-shares percent)))
                ;; CR-02
                ;; if there are any residual collateral, convert to token
                (bal-x-to-y (if (is-eq balance-x u0) 
                                u0 
                                (if (is-eq token-x token-y)
                                    balance-x
                                    (begin
                                        (as-contract (try! (contract-call? .alex-vault transfer-ft collateral balance-x tx-sender)))
                                        ;; (as-contract (try! (contract-call? .fixed-weight-pool swap-helper collateral token u50000000 u50000000 balance-x none)))
                                        (as-contract
                                            (if (is-eq token-x .token-wstx)
                                                (get dy (try! (contract-call? .fixed-weight-pool swap-wstx-for-y token u50000000 balance-x none)))
                                                (if (is-eq token-y .token-wstx)
                                                    (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-wstx collateral u50000000 balance-x none)))
                                                    (if (is-some (contract-call? .fixed-weight-pool get-pool-exists collateral token u50000000 u50000000))
                                                        (get dy (try! (contract-call? .fixed-weight-pool swap-x-for-y collateral token u50000000 u50000000 balance-x none)))
                                                        (get dx (try! (contract-call? .fixed-weight-pool swap-y-for-x token collateral u50000000 u50000000 balance-x none)))
                                                    )
                                                )
                                            )                                        
                                        )
                                    )                                    
                                )
                            )
                )
                (bal-y-key (if (<= (+ balance-y bal-x-to-y) yield-supply) u0 (- (+ balance-y bal-x-to-y) yield-supply)))
                (shares-to-key (div-down shares key-supply))
                (bal-y-reduce (mul-down bal-y-key shares-to-key))   

                (pool-updated (merge pool {
                    key-supply: (if (<= key-supply shares) u0 (- key-supply shares)),
                    balance-x: u0,
                    balance-y: (- (+ balance-y bal-x-to-y) bal-y-reduce)
                    })
                )            
            )

            (asserts! (is-eq (get key-token pool) (contract-of the-key-token)) ERR-INVALID-TOKEN)        
            
            (and (> bal-y-reduce u0) (try! (contract-call? .alex-vault transfer-ft token bal-y-reduce tx-sender)))
        
            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-updated)
            (try! (contract-call? the-key-token burn-fixed expiry shares tx-sender))
            (print { object: "pool", action: "liquidity-removed", data: pool-updated })
            (ok {dx: u0, dy: bal-y-reduce})
        )        
    )
)

;; @desc swap collateral with token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param dx; amount of collateral to be swapped
;; @param min-dy; max slippage
;; @post collateral; sender transfers exactly dx collateral to alex-vault
;; @returns (response (tuple uint uint) uint)
(define-public (swap-x-for-y (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (dx uint) (min-dy (optional uint)))
    (begin
        (asserts! (> dx u0) ERR-INVALID-LIQUIDITY)
        ;; swap is supported only if token /= collateral
        (asserts! (not (is-eq token collateral)) ERR-INVALID-POOL)
        ;; CR-03
        (asserts! (<= (* block-height ONE_8) expiry) ERR-EXPIRY)            
        (let
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                ;; (strike (get strike pool))
                ;; (bs-vol (get bs-vol pool)) 
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))

                ;; every swap call updates the weights
                (weight-y (unwrap! (get-weight-y-with-spot token collateral expiry (try! (get-spot token collateral))) ERR-GET-WEIGHT-FAIL))
                (weight-x (- ONE_8 weight-y))            
            
                ;; fee = dx * fee-rate-x
                (fee (mul-up dx (get fee-rate-x pool)))
                (fee-rebate (mul-down fee (get fee-rebate pool)))
                (dx-net-fees (if (<= dx fee) u0 (- dx fee)))
                (dy (try! (get-y-given-x token collateral expiry dx-net-fees)))

                (pool-updated
                    (merge pool
                        {
                            balance-x: (+ balance-x dx-net-fees fee-rebate),
                            balance-y: (if (<= balance-y dy) u0 (- balance-y dy)),
                            weight-x: weight-x,
                            weight-y: weight-y                    
                        }
                    )
                )
            )

            (asserts! (< (default-to u0 min-dy) dy) ERR-EXCEEDS-MAX-SLIPPAGE)

            (unwrap! (contract-call? collateral transfer-fixed dx tx-sender .alex-vault none) ERR-TRANSFER-FAILED)
            (try! (contract-call? .alex-vault transfer-ft token dy tx-sender))
            (try! (contract-call? .alex-reserve-pool add-to-balance token-x (- fee fee-rebate)))

            ;; post setting
            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-updated)
            (print { object: "pool", action: "swap-x-for-y", data: pool-updated })
            (ok {dx: dx-net-fees, dy: dy})
        )
    )
)

;; @desc swap token with collateral
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param dy; amount of token to be swapped
;; @param min-dx; max slippage
;; @post token; sender transfers exactly dy token to alex-vault
;; @returns (response (tuple uint uint) uint)
(define-public (swap-y-for-x (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (dy uint) (min-dx (optional uint)))
    (begin
        (asserts! (> dy u0) ERR-INVALID-LIQUIDITY)    
        ;; swap is supported only if token /= collateral
        (asserts! (not (is-eq token collateral)) ERR-INVALID-POOL)   
        ;; CR-03
        (asserts! (<= (* block-height ONE_8) expiry) ERR-EXPIRY)              
        (let
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                ;; (strike (get strike pool))
                ;; (bs-vol (get bs-vol pool))
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))

                ;; every swap call updates the weights
                (weight-y (unwrap! (get-weight-y-with-spot token collateral expiry (try! (get-spot token collateral))) ERR-GET-WEIGHT-FAIL))
                (weight-x (- ONE_8 weight-y))   

                ;; fee = dy * fee-rate-y
                (fee (mul-up dy (get fee-rate-y pool)))
                (fee-rebate (mul-down fee (get fee-rebate pool)))
                (dy-net-fees (if (<= dy fee) u0 (- dy fee)))
                (dx (try! (get-x-given-y token collateral expiry dy-net-fees)))        

                (pool-updated
                    (merge pool
                        {
                            balance-x: (if (<= balance-x dx) u0 (- balance-x dx)),
                            balance-y: (+ balance-y dy-net-fees fee-rebate),
                            weight-x: weight-x,
                            weight-y: weight-y                        
                        }
                    )
                )
            )

            (asserts! (< (default-to u0 min-dx) dx) ERR-EXCEEDS-MAX-SLIPPAGE)

            (try! (contract-call? .alex-vault transfer-ft collateral dx tx-sender))
            (unwrap! (contract-call? token transfer-fixed dy tx-sender .alex-vault none) ERR-TRANSFER-FAILED)
            (try! (contract-call? .alex-reserve-pool add-to-balance token-y (- fee fee-rebate)))

            ;; post setting
            (map-set pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry } pool-updated)
            (print { object: "pool", action: "swap-y-for-x", data: pool-updated })
            (ok {dx: dx, dy: dy-net-fees})
        )
    )
)

;; @desc get-fee-rebate
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @returns (response uint uint)
(define-read-only (get-fee-rebate (token <ft-trait>) (collateral <ft-trait>) (expiry uint)) 
   (ok (get fee-rebate (try! (get-pool-details token collateral expiry))))  
)

;; @desc set-fee-rebate
;; @restricted contract-owner
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param fee-rebate; new fee-rebate
;; @returns (response bool uint)
(define-public (set-fee-rebate (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (fee-rebate uint))
    (let 
        (
            (pool (try! (get-pool-details token collateral expiry)))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map 
            { 
                token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry 
            }
            (merge pool { fee-rebate: fee-rebate })
        )
        (ok true)     
    )
)

;; @desc get-fee-rate-x
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @returns (response uint uint)
(define-read-only (get-fee-rate-x (token <ft-trait>) (collateral <ft-trait>) (expiry uint)) 
   (ok (get fee-rate-x (try! (get-pool-details token collateral expiry))))  
)

;; @desc get-fee-rate-y
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @returns (response uint uint)
(define-read-only (get-fee-rate-y (token <ft-trait>) (collateral <ft-trait>) (expiry uint)) 
   (ok (get fee-rate-y (try! (get-pool-details token collateral expiry))))  
)

;; @desc set-fee-rate-x
;; @restricted fee-to-address
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param fee-rate-x; new fee-rate-x
;; @returns (response bool uint)
(define-public (set-fee-rate-x (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (fee-rate-x uint))
    (let 
        (
            (pool (try! (get-pool-details token collateral expiry)))
        )
        (asserts! (is-eq contract-caller (get fee-to-address pool)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map 
            { 
                token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry 
            }
            (merge pool { fee-rate-x: fee-rate-x })
        )
        (ok true)     
    )
)

;; @desc set-fee-rate-y
;; @restricted fee-to-address
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param fee-rate-y; new fee-rate-y
;; @returns (response bool uint)
(define-public (set-fee-rate-y (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (fee-rate-y uint))
    (let 
        (         
            (pool (try! (get-pool-details token collateral expiry)))
        )
        (asserts! (is-eq contract-caller (get fee-to-address pool)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map 
            { 
                token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry
            }
            (merge pool { fee-rate-y: fee-rate-y })
        )
        (ok true)     
    )
)

;; @desc get-fee-to-address (multisig of the pool)
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @returns (response principal uint)
(define-read-only (get-fee-to-address (token <ft-trait>) (collateral <ft-trait>) (expiry uint))
    (let 
        (
            (token-x (contract-of collateral))
            (token-y (contract-of token))                
            (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
        )
        (ok (get fee-to-address pool))
    )
)

;; @desc units of token given units of collateral
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param dx; amount of collateral being added
;; @returns (response uint uint)
(define-read-only (get-y-given-x (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (dx uint))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry }) ERR-INVALID-POOL))
        )
        (contract-call? .weighted-equation get-y-given-x
            (get balance-x pool)
            (get balance-y pool)
            (get weight-x pool)
            (get weight-y pool)
            dx
        )
    )
)

;; @desc units of collateral given units of token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param dy; amount of token being added
;; @returns (response uint uint)
(define-read-only (get-x-given-y (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (dy uint))
	(let
		(
			(pool (unwrap! (map-get? pools-data-map
				{ token-x: (contract-of collateral), token-y: (contract-of token), expiry: expiry })
				ERR-INVALID-POOL)
			)
		)
		(contract-call? .weighted-equation get-x-given-y 
			(get balance-x pool) 
			(get balance-y pool) 
			(get weight-x pool) 
			(get weight-y pool) 
			dy
		)
	)
)

;; @desc units of collateral required for a target price
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param price; target price
;; @returns (response uint uint)
(define-read-only (get-x-given-price (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (price uint))
    (let 
        (
            (token-x (contract-of collateral))
            (token-y (contract-of token))
            (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
            (balance-x (get balance-x pool))
            (balance-y (get balance-y pool))
            (weight-x (get weight-x pool))
            (weight-y (get weight-y pool))         
        )
        (contract-call? .weighted-equation get-x-given-price balance-x balance-y weight-x weight-y price)
    )
)

;; @desc units of token required for a target price
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param price; target price
;; @returns (response uint uint)
(define-read-only (get-y-given-price (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (price uint))
    (let 
        (
            (token-x (contract-of collateral))
            (token-y (contract-of token))
            (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
            (balance-x (get balance-x pool))
            (balance-y (get balance-y pool))
            (weight-x (get weight-x pool))
            (weight-y (get weight-y pool))         
        )
        (contract-call? .weighted-equation get-y-given-price balance-x balance-y weight-x weight-y price)
    )
)

(define-read-only (get-token-given-position (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (dx uint))
    (get-token-given-position-with-spot token collateral expiry (try! (get-spot token collateral)) dx)
)

;; @desc units of yield-/key-token to be minted given amount of collateral being added (single sided liquidity)
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param dx; amount of collateral being added
;; @returns (response (tuple uint uint) uint)
(define-private (get-token-given-position-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint) (dx uint))
    (begin
        (asserts! (< (* block-height ONE_8) expiry) ERR-EXPIRY)
        (let 
            (
                (ltv (try! (get-ltv-with-spot token collateral expiry spot)))
                (dy (if (is-eq (contract-of token) (contract-of collateral))
                        dx
                        ;; (try! (contract-call? .fixed-weight-pool get-helper collateral token u50000000 u50000000 dx))                    
                        (if (is-eq (contract-of collateral) .token-wstx)
                            (try! (contract-call? .fixed-weight-pool get-y-given-wstx token u50000000 dx))
                            (if (is-eq (contract-of token) .token-wstx)
                                (try! (contract-call? .fixed-weight-pool get-wstx-given-y collateral u50000000 dx))
                                (if (is-some (contract-call? .fixed-weight-pool get-pool-exists collateral token u50000000 u50000000))
                                    (try! (contract-call? .fixed-weight-pool get-y-given-x collateral token u50000000 u50000000 dx))
                                    (try! (contract-call? .fixed-weight-pool get-x-given-y token collateral u50000000 u50000000 dx))
                                )
                            )
                        )
                    )
                )
                (ltv-dy (mul-down ltv dy))
            )

            (ok {yield-token: ltv-dy, key-token: ltv-dy})
        )
    )
)

(define-read-only (get-position-given-mint (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (shares uint))
    (get-position-given-mint-with-spot token collateral expiry (try! (get-spot token collateral)) shares)
)

;; @desc units of token/collateral required to mint given units of yield-/key-token
;; @desc returns dx (single liquidity) based on dx-weighted and dy-weighted
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param shares; units of yield-/key-token to be minted
;; @returns (response (tuple uint uint uint) uint)
(define-private (get-position-given-mint-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint) (shares uint))
    (begin
        (asserts! (< (* block-height ONE_8) expiry) ERR-EXPIRY) ;; mint supported until, but excl., expiry
        (let 
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))
                (total-supply (get yield-supply pool)) ;; prior to maturity, yield-supply == key-supply, so we use yield-supply
                (weight-x (get weight-x pool))
                (weight-y (get weight-y pool))
            
                (ltv (try! (get-ltv-with-spot token collateral expiry spot)))

                (pos-data (unwrap! (contract-call? .weighted-equation get-position-given-mint balance-x balance-y weight-x weight-y total-supply shares) ERR-WEIGHTED-EQUATION-CALL))

                (dx-weighted (get dx pos-data))
                (dy-weighted (get dy pos-data))

                ;; always convert to collateral ccy
                (dy-to-dx (if (is-eq token-x token-y)
                            dy-weighted
                            ;; (try! (contract-call? .fixed-weight-pool get-helper collateral token u50000000 u50000000 dy-weighted))                    
                            (if (is-eq (contract-of collateral) .token-wstx)
                                (try! (contract-call? .fixed-weight-pool get-y-given-wstx token u50000000 dy-weighted))
                                (if (is-eq (contract-of token) .token-wstx)
                                    (try! (contract-call? .fixed-weight-pool get-wstx-given-y collateral u50000000 dy-weighted))
                                    (if (is-some (contract-call? .fixed-weight-pool get-pool-exists collateral token u50000000 u50000000))
                                        (try! (contract-call? .fixed-weight-pool get-y-given-x collateral token u50000000 u50000000 dy-weighted))
                                        (try! (contract-call? .fixed-weight-pool get-x-given-y token collateral u50000000 u50000000 dy-weighted))
                                    )
                                )
                            )                            
                        )
                )   
                (dx (+ dx-weighted dy-to-dx))
            )
            (ok {dx: dx, dx-weighted: dx-weighted, dy-weighted: dy-weighted})
        )
    )
)

(define-read-only (get-position-given-burn-key (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (shares uint))
    (get-position-given-burn-key-with-spot token collateral expiry (try! (get-spot token collateral)) shares)
)

;; @desc units of token/collateral to be returned after burning given units of yield-/key-token
;; @param token; borrow token
;; @param collateral; collateral token
;; @param expiry; borrow expiry
;; @param shares; units of yield-/key-token to be burnt
;; @returns (response (tuple uint uint) uint)
(define-private (get-position-given-burn-key-with-spot (token <ft-trait>) (collateral <ft-trait>) (expiry uint) (spot uint) (shares uint))
    (begin         
        (let 
            (
                (token-x (contract-of collateral))
                (token-y (contract-of token))
                (pool (unwrap! (map-get? pools-data-map { token-x: token-x, token-y: token-y, expiry: expiry }) ERR-INVALID-POOL))
                (balance-x (get balance-x pool))
                (balance-y (get balance-y pool))  
                (yield-supply (get yield-supply pool))                  
                (key-supply (get key-supply pool))
                (weight-x (get weight-x pool))
                (weight-y (get weight-y pool))
                (pool-value-in-y (try! (get-pool-value-in-token-with-spot token collateral expiry spot)))
                (key-value-in-y (if (<= pool-value-in-y yield-supply) u0 (- pool-value-in-y yield-supply)))
                (key-to-pool (div-down key-value-in-y pool-value-in-y))
                (shares-to-key (div-down shares key-supply))
                (shares-to-pool (mul-down key-to-pool shares-to-key))
                    
                (dx (mul-down shares-to-pool balance-x))
                (dy (mul-down shares-to-pool balance-y))
            )
            (ok {dx: dx, dy: dy})
        )
    )
)


;; math-fixed-point
;; Fixed Point Math
;; following https://github.com/balancer-labs/balancer-monorepo/blob/master/pkg/solidity-utils/contracts/math/FixedPoint.sol

;; TODO: overflow causes runtime error, should handle before operation rather than after

;; With 8 fixed digits you would have a maximum error of 0.5 * 10^-8 in each entry, 
;; which could aggregate to about 8 x 0.5 * 10^-8 = 4 * 10^-8 relative error 
;; (i.e. the last digit of the result may be completely lost to this error).
(define-constant MAX_POW_RELATIVE_ERROR u4) 

;; public functions
;;

;; @desc mul-down
;; @params a
;; @param b
;; @returns uint
(define-read-only (mul-down (a uint) (b uint))
    (/ (* a b) ONE_8)
)

;; @desc mul-up
;; @params a
;; @param b
;; @returns uint
(define-read-only (mul-up (a uint) (b uint))
    (let
        (
            (product (* a b))
       )
        (if (is-eq product u0)
            u0
            (+ u1 (/ (- product u1) ONE_8))
       )
   )
)

;; @desc div-down
;; @params a
;; @param b
;; @returns uint
(define-read-only (div-down (a uint) (b uint))
    (if (is-eq a u0)
        u0
        (/ (* a ONE_8) b)
    )
)

;; @desc div-up
;; @params a
;; @param b
;; @returns uint
(define-read-only (div-up (a uint) (b uint))
    (if (is-eq a u0)
        u0
        (+ u1 (/ (- (* a ONE_8) u1) b))
    )
)

;; @desc pow-down
;; @params a
;; @param b
;; @returns uint
(define-read-only (pow-down (a uint) (b uint))    
    (let
        (
            (raw (unwrap-panic (pow-fixed a b)))
            (maxor (+ u1 (mul-up raw MAX_POW_RELATIVE_ERROR)))
        )
        (if (< raw maxor)
            u0
            (- raw maxor)
        )
    )
)

;; math-log-exp
;; Exponentiation and logarithm functions for 8 decimal fixed point numbers (both base and exponent/argument).
;; Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural 
;; exponentiation and logarithm (where the base is Euler's number).
;; Reference: https://github.com/balancer-labs/balancer-monorepo/blob/master/pkg/solidity-utils/contracts/math/LogExpMath.sol
;; MODIFIED: because we use only 128 bits instead of 256, we cannot do 20 decimal or 36 decimal accuracy like in Balancer. 

;; constants
;;
;; All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
;; two numbers, and multiply by ONE when dividing them.
;; All arguments and return values are 8 decimal fixed point numbers.
(define-constant iONE_8 (pow 10 8))
(define-constant ONE_10 (pow 10 10))

;; The domain of natural exponentiation is bound by the word size and number of decimals used.
;; The largest possible result is (2^127 - 1) / 10^8, 
;; which makes the largest exponent ln((2^127 - 1) / 10^8) = 69.6090111872.
;; The smallest possible result is 10^(-8), which makes largest negative argument ln(10^(-8)) = -18.420680744.
;; We use 69.0 and -18.0 to have some safety margin.
(define-constant MAX_NATURAL_EXPONENT (* 69 iONE_8))
(define-constant MIN_NATURAL_EXPONENT (* -18 iONE_8))

(define-constant MILD_EXPONENT_BOUND (/ (pow u2 u126) (to-uint iONE_8)))

;; Because largest exponent is 69, we start from 64
;; The first several a_n are too large if stored as 8 decimal numbers, and could cause intermediate overflows.
;; Instead we store them as plain integers, with 0 decimals.
(define-constant x_a_list_no_deci (list 
{x_pre: 6400000000, a_pre: 6235149080811616882910000000, use_deci: false} ;; x1 = 2^6, a1 = e^(x1)
))
;; 8 decimal constants
(define-constant x_a_list (list 
{x_pre: 3200000000, a_pre: 7896296018268069516100, use_deci: true} ;; x2 = 2^5, a2 = e^(x2)
{x_pre: 1600000000, a_pre: 888611052050787, use_deci: true} ;; x3 = 2^4, a3 = e^(x3)
{x_pre: 800000000, a_pre: 298095798704, use_deci: true} ;; x4 = 2^3, a4 = e^(x4)
{x_pre: 400000000, a_pre: 5459815003, use_deci: true} ;; x5 = 2^2, a5 = e^(x5)
{x_pre: 200000000, a_pre: 738905610, use_deci: true} ;; x6 = 2^1, a6 = e^(x6)
{x_pre: 100000000, a_pre: 271828183, use_deci: true} ;; x7 = 2^0, a7 = e^(x7)
{x_pre: 50000000, a_pre: 164872127, use_deci: true} ;; x8 = 2^-1, a8 = e^(x8)
{x_pre: 25000000, a_pre: 128402542, use_deci: true} ;; x9 = 2^-2, a9 = e^(x9)
{x_pre: 12500000, a_pre: 113314845, use_deci: true} ;; x10 = 2^-3, a10 = e^(x10)
{x_pre: 6250000, a_pre: 106449446, use_deci: true} ;; x11 = 2^-4, a11 = e^x(11)
))

(define-constant ERR_X_OUT_OF_BOUNDS (err u5009))
(define-constant ERR_Y_OUT_OF_BOUNDS (err u5010))
(define-constant ERR_PRODUCT_OUT_OF_BOUNDS (err u5011))
(define-constant ERR_INVALID_EXPONENT (err u5012))
(define-constant ERR_OUT_OF_BOUNDS (err u5013))

;; private functions
;;

;; Internal natural logarithm (ln(a)) with signed 8 decimal fixed point argument.
;; @desc ln-priv
;; @params a
;; @returns int
(define-private (ln-priv (a int))
  (let
    (
      (a_sum_no_deci (fold accumulate_division x_a_list_no_deci {a: a, sum: 0}))
      (a_sum (fold accumulate_division x_a_list {a: (get a a_sum_no_deci), sum: (get sum a_sum_no_deci)}))
      (out_a (get a a_sum))
      (out_sum (get sum a_sum))
      (z (/ (* (- out_a iONE_8) iONE_8) (+ out_a iONE_8)))
      (z_squared (/ (* z z) iONE_8))
      (div_list (list 3 5 7 9 11))
      (num_sum_zsq (fold rolling_sum_div div_list {num: z, seriesSum: z, z_squared: z_squared}))
      (seriesSum (get seriesSum num_sum_zsq))
      (r (+ out_sum (* seriesSum 2)))
   )
    (ok r)
 )
)

;; @desc accumulate_division
;; @params x_a_pre; tuple
;; @params rolling_a_sum; tuple
;; @returns tuple
(define-private (accumulate_division (x_a_pre (tuple (x_pre int) (a_pre int) (use_deci bool))) (rolling_a_sum (tuple (a int) (sum int))))
  (let
    (
      (a_pre (get a_pre x_a_pre))
      (x_pre (get x_pre x_a_pre))
      (use_deci (get use_deci x_a_pre))
      (rolling_a (get a rolling_a_sum))
      (rolling_sum (get sum rolling_a_sum))
   )
    (if (>= rolling_a (if use_deci a_pre (* a_pre iONE_8)))
      {a: (/ (* rolling_a (if use_deci iONE_8 1)) a_pre), sum: (+ rolling_sum x_pre)}
      {a: rolling_a, sum: rolling_sum}
   )
 )
)

;; @desc rolling_sum_div
;; @params n
;; @params rolling; tuple
;; @returns tuple
(define-private (rolling_sum_div (n int) (rolling (tuple (num int) (seriesSum int) (z_squared int))))
  (let
    (
      (rolling_num (get num rolling))
      (rolling_sum (get seriesSum rolling))
      (z_squared (get z_squared rolling))
      (next_num (/ (* rolling_num z_squared) iONE_8))
      (next_sum (+ rolling_sum (/ next_num n)))
   )
    {num: next_num, seriesSum: next_sum, z_squared: z_squared}
 )
)

;; Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
;; arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
;; x^y = exp(y * ln(x)).
;; Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
;; @desc pow-priv
;; @params x
;; @params y
;; @returns (response uint)
(define-private (pow-priv (x uint) (y uint))
  (let
    (
      (x-int (to-int x))
      (y-int (to-int y))
      (lnx (unwrap-panic (ln-priv x-int)))
      (logx-times-y (/ (* lnx y-int) iONE_8))
    )
    (asserts! (and (<= MIN_NATURAL_EXPONENT logx-times-y) (<= logx-times-y MAX_NATURAL_EXPONENT)) ERR_PRODUCT_OUT_OF_BOUNDS)
    (ok (to-uint (unwrap-panic (exp-fixed logx-times-y))))
  )
)

;; @desc exp-pos
;; @params x
;; @returns (response uint)
(define-private (exp-pos (x int))
  (begin
    (asserts! (and (<= 0 x) (<= x MAX_NATURAL_EXPONENT)) ERR_INVALID_EXPONENT)
    (let
      (
        ;; For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
        ;; it and compute the accumulated product.
        (x_product_no_deci (fold accumulate_product x_a_list_no_deci {x: x, product: 1}))
        (x_adj (get x x_product_no_deci))
        (firstAN (get product x_product_no_deci))
        (x_product (fold accumulate_product x_a_list {x: x_adj, product: iONE_8}))
        (product_out (get product x_product))
        (x_out (get x x_product))
        (seriesSum (+ iONE_8 x_out))
        (div_list (list 2 3 4 5 6 7 8 9 10 11 12))
        (term_sum_x (fold rolling_div_sum div_list {term: x_out, seriesSum: seriesSum, x: x_out}))
        (sum (get seriesSum term_sum_x))
     )
      (ok (* (/ (* product_out sum) iONE_8) firstAN))
   )
 )
)

;; @desc accumulate_product
;; @params x_a_pre ; tuple
;; @params rolling_x_p; tuple
;; @returns tuple
(define-private (accumulate_product (x_a_pre (tuple (x_pre int) (a_pre int) (use_deci bool))) (rolling_x_p (tuple (x int) (product int))))
  (let
    (
      (x_pre (get x_pre x_a_pre))
      (a_pre (get a_pre x_a_pre))
      (use_deci (get use_deci x_a_pre))
      (rolling_x (get x rolling_x_p))
      (rolling_product (get product rolling_x_p))
   )
    (if (>= rolling_x x_pre)
      {x: (- rolling_x x_pre), product: (/ (* rolling_product a_pre) (if use_deci iONE_8 1))}
      {x: rolling_x, product: rolling_product}
   )
 )
)

;; @desc rolling_div_sum
;; @params n
;; @params rolling; tuple
;; @returns tuple
(define-private (rolling_div_sum (n int) (rolling (tuple (term int) (seriesSum int) (x int))))
  (let
    (
      (rolling_term (get term rolling))
      (rolling_sum (get seriesSum rolling))
      (x (get x rolling))
      (next_term (/ (/ (* rolling_term x) iONE_8) n))
      (next_sum (+ rolling_sum next_term))
   )
    {term: next_term, seriesSum: next_sum, x: x}
 )
)

;; public functions
;;

;; @desc get-exp-bound
;; @returns (response uint)
(define-read-only (get-exp-bound)
  (ok MILD_EXPONENT_BOUND)
)

;; Exponentiation (x^y) with unsigned 8 decimal fixed point base and exponent.
;; @desc pow-fixed
;; @params x
;; @params y
;; @returns (response uint)
(define-read-only (pow-fixed (x uint) (y uint))
  (begin
    ;; The ln function takes a signed value, so we need to make sure x fits in the signed 128 bit range.
    (asserts! (< x (pow u2 u127)) ERR_X_OUT_OF_BOUNDS)

    ;; This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 128 bit range.
    (asserts! (< y MILD_EXPONENT_BOUND) ERR_Y_OUT_OF_BOUNDS)

    (if (is-eq y u0) 
      (ok (to-uint iONE_8))
      (if (is-eq x u0) 
        (ok u0)
        (pow-priv x y)
      )
    )
  )
)

;; Natural exponentiation (e^x) with signed 8 decimal fixed point exponent.
;; Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
;; @desc exp-fixed
;; @params x
;; @returns uint
(define-read-only (exp-fixed (x int))
  (begin
    (asserts! (and (<= MIN_NATURAL_EXPONENT x) (<= x MAX_NATURAL_EXPONENT)) ERR_INVALID_EXPONENT)
    (if (< x 0)
      ;; We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
      ;; fits in the signed 128 bit range (as it is larger than MIN_NATURAL_EXPONENT).
      ;; Fixed point division requires multiplying by iONE_8.
      (ok (/ (* iONE_8 iONE_8) (unwrap-panic (exp-pos (* -1 x)))))
      (exp-pos x)
    )
  )
)

;; Natural logarithm (ln(a)) with signed 8 decimal fixed point argument.
;; @desc ln-fixed
;; @params a
;; @returns uint
(define-read-only (ln-fixed (a int))
  (begin
    (asserts! (> a 0) ERR_OUT_OF_BOUNDS)
    (if (< a iONE_8)
      ;; Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)).
      ;; If a is less than one, 1/a will be greater than one.
      ;; Fixed point division requires multiplying by iONE_8.
      (ok (- 0 (unwrap-panic (ln-priv (/ (* iONE_8 iONE_8) a)))))
      (ln-priv a)
   )
 )
)


(define-public (execute-update (token <ft-trait>) (amount uint) (memo-uint uint) )
    (let
        (   
            ;; gross amount * ltv / price = amount
            ;; gross amount = amount * price / ltv
            ;;(memo-uint (buff-to-uint (unwrap! memo ERR-EXPIRY-IS-NONE)))        
            (ltv (try! (get-ltv .token-usda .token-wstx memo-uint)))
            (price (try! (contract-call? .yield-token-pool get-price memo-uint .yield-usda)))
            (gross-amount (mul-up amount (div-down price ltv)))
            (minted-yield-token (get yield-token (try! (add-to-position .token-usda .token-wstx memo-uint .yield-usda .key-usda-wstx gross-amount))))
            (swapped-token (get dx (try! (contract-call? .yield-token-pool swap-y-for-x memo-uint .yield-usda .token-usda minted-yield-token none))))
        )
        ;; swap token to collateral so we can return flash-loan
        ;;(try! (contract-call? .fixed-weight-pool swap-helper .token-usda .token-wstx u50000000 u50000000 swapped-token none))        
        ;; (print { object: "flash-loan-user-margin-wstx-usda", action: "execute", data: gross-amount })
        (ok swapped-token)
    )
)
