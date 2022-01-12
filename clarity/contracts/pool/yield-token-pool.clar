(impl-trait .trait-ownable.ownable-trait)
(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait sft-trait .trait-semi-fungible.semi-fungible-trait)



;; yield-token-pool
(define-constant ONE_8 (pow u10 u8)) ;; 8 decimal places
(define-constant MAX_T u85000000)

(define-constant ERR-INVALID-BALANCE (err u1001))
(define-constant ERR-INVALID-POOL (err u2001))
(define-constant ERR-INVALID-LIQUIDITY (err u2003))
(define-constant ERR-TRANSFER-FAILED (err u3000))
(define-constant ERR-POOL-ALREADY-EXISTS (err u2000))
(define-constant ERR-TOO-MANY-POOLS (err u2004))
(define-constant ERR-PERCENT-GREATER-THAN-ONE (err u5000))
(define-constant ERR-NO-FEE (err u2005))
(define-constant ERR-NO-FEE-Y (err u2006))
(define-constant ERR-INVALID-EXPIRY (err u2009))
(define-constant ERR-MATH-CALL (err u4003))
(define-constant ERR-GET-EXPIRY-FAIL-ERR (err u2013))
(define-constant ERR-DY-BIGGER-THAN-AVAILABLE (err u2016))
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-EXCEEDS-MAX-SLIPPAGE (err u2020))
(define-constant ERR-INVALID-TOKEN (err u2026))
(define-constant ERR-ORACLE-NOT-ENABLED (err u7002))
(define-constant ERR-ORACLE-ALREADY-ENABLED (err u7003))
(define-constant ERR-ORACLE-AVERAGE-BIGGER-THAN-ONE (err u7004))

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
(define-map pools-map
  { pool-id: uint }
  {
    yield-token: principal, ;; yield-token, dy
    expiry: uint
  }
)

(define-map pools-data-map
  {
    yield-token: principal, 
    expiry: uint
  }
  {
    total-supply: uint,    
    balance-token: uint, ;; dx    
    balance-yield-token: uint, ;; dy_actual
    balance-virtual: uint, ;; dy_virtual
    fee-to-address: principal,
    pool-token: principal,
    fee-rate-token: uint,    
    fee-rate-yield-token: uint,
    fee-rebate: uint,
    listed: uint,
    oracle-enabled: bool,
    oracle-average: uint,
    oracle-resilient: uint,
    token-trait: principal
  }
)

(define-data-var pool-count uint u0)
(define-data-var pools-list (list 500 uint) (list))

;; 4 years based on 2102400 blocks per year (i.e. 15 secs per block)
(define-data-var max-expiry uint (scale-up u8409600))

;; @desc get-max-expiry
;; @returns uint
(define-read-only (get-max-expiry)
    (var-get max-expiry)
)

;; @desc set-max-expiry
;; @restricted contract-owner
;; @param new-max-expiry; new max-expiry
;; @returns (response bool uint)
(define-public (set-max-expiry (new-max-expiry uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        ;; MI-05
        (asserts! (> new-max-expiry (* block-height ONE_8)) ERR-INVALID-EXPIRY)
        (ok (var-set max-expiry new-max-expiry)) 
    )
)

;; @desc get-t
;; @desc get time-to-maturity as a function of max-expiry
;; @param expiry; when contract expiries
;; @param listed; when contract was listed
;; @returns (response uint uint)
(define-read-only (get-t (expiry uint) (listed uint))
    (begin
        (asserts! (> (var-get max-expiry) expiry) ERR-INVALID-EXPIRY)
        (asserts! (> (var-get max-expiry) (* block-height ONE_8)) ERR-INVALID-EXPIRY)        
        (let
            (
                (t (div-down
                    (if (< expiry (* block-height ONE_8)) u0 (- expiry (* block-height ONE_8)))
                    (- (var-get max-expiry) listed)))
            )
            (ok (if (< t MAX_T) t MAX_T)) ;; to avoid numerical error
        )
    )
)

;; @desc get-pool-count
;; @returns uint
(define-read-only (get-pool-count)
    (var-get pool-count)
)

;; @desc get-pool-contracts
;; @param pool-id; pool-id
;; @returns (response (tutple) uint)
(define-read-only (get-pool-contracts (pool-id uint))
    (ok (unwrap! (map-get? pools-map {pool-id: pool-id}) ERR-INVALID-POOL))
)

;; @desc get-pools
;; @returns map of get-pool-contracts
(define-read-only (get-pools)
    (ok (map get-pool-contracts (var-get pools-list)))
)

;; immunefi-4384
(define-read-only (get-pools-by-ids (pool-ids (list 26 uint)))
  (ok (map get-pool-contracts pool-ids))
)

;; @desc get-pool-details
;; @param yield-token-trait; yield-token
;; @returns (response (tuple) uint)
(define-read-only (get-pool-details (expiry uint) (yield-token principal))
    (ok (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
)

;; @desc get-yield
;; @desc note yield is not annualised
;; @param yield-token-trait; yield-token
;; @returns (response uint uint)
(define-read-only (get-yield (expiry uint) (yield-token principal))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry}) ERR-INVALID-POOL))
            (listed (get listed pool))
            (balance-token (get balance-token pool)) 
            (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
            (t-value (try! (get-t expiry listed)))
        )
        (get-yield-from-equation balance-token balance-yield-token t-value)
    )
)

;; @desc get-price
;; @param yield-token-trait; yield-token
;; @returns (response uint uint)
(define-read-only (get-price (expiry uint) (yield-token principal))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
            (listed (get listed pool))
            (balance-token (get balance-token pool)) 
            (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
            (t-value (try! (get-t expiry listed)))
        )
        (get-price-from-equation balance-token balance-yield-token t-value)
    )
)


;; @desc get-price
;; @desc b_y = balance-yield-token
;; @desc b_x = balance-token
;; @desc price = (b_y / b_x) ^ t
;; @param balance-x; balance of token-x (token)
;; @param balance-y; balance of token-y (yield-token)
;; @param t; time-to-maturity
;; @returns (response uint uint)
(define-read-only (get-price-from-equation (balance-x uint) (balance-y uint) (t uint))
  (begin
    (asserts! (>= balance-y balance-x) ERR-INVALID-BALANCE)      
    (ok (pow-up (div-down balance-y balance-x) t))
  )
)

;; @desc get-yield
;; @param balance-x; balance of token-x (token)
;; @param balance-y; balance of token-y (yield-token)
;; @param t; time-to-maturity
;; @returns (response uint uint)
(define-read-only (get-yield-from-equation (balance-x uint) (balance-y uint) (t uint))
  (begin
    (asserts! (>= balance-y balance-x) ERR-INVALID-BALANCE)
    (let
        (
            (price (pow-up (div-down balance-y balance-x) t))
        )
        (if (<= price ONE_8) (ok u0) (ok (- price ONE_8)))
    )
  )
)

;; @desc get-oracle-enabled
;; @param yield-token-trait; yield-token
;; @returns (response bool uint)
(define-read-only (get-oracle-enabled (expiry uint) (yield-token principal))
    (ok (get oracle-enabled (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL)))
)

;; @desc set-oracle-enabled
;; @desc oracle can only be enabled
;; @restricted contract-owner
;; @param yield-token-trait; yield-token
;; @returns (response bool uint)
(define-public (set-oracle-enabled (expiry uint) (yield-token principal))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
            (pool-updated (merge pool {oracle-enabled: true}))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get oracle-enabled pool)) ERR-ORACLE-ALREADY-ENABLED)
        (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)
        (ok true)
    )    
)

;; @desc get-oracle-average
;; @desc returns the moving average used to determine oracle price
;; @param yield-token-trait; yield-token
;; @returns (response uint uint)
(define-read-only (get-oracle-average (expiry uint) (yield-token principal))
    (ok (get oracle-average (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL)))
)

;; @desc set-oracle-average
;; @restricted contract-owner
;; @param yield-token-trait; yield-token
;; @returns (response bool uint)
(define-public (set-oracle-average (expiry uint) (yield-token principal) (new-oracle-average uint))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
            (pool-updated (merge pool {
                oracle-average: new-oracle-average,
                oracle-resilient: (try! (get-oracle-instant expiry yield-token))
                }))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (get oracle-enabled pool) ERR-ORACLE-NOT-ENABLED)
        (asserts! (< new-oracle-average ONE_8) ERR-ORACLE-AVERAGE-BIGGER-THAN-ONE)
        (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)
        (ok true)
    )    
)

;; @desc get-oracle-resilient
;; @desc price-oracle that is less up to date but more resilient to manipulation
;; @param yield-token-trait; yield-token
;; @returns (response uint uint)
(define-read-only (get-oracle-resilient (expiry uint) (yield-token principal))
    (let
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (asserts! (get oracle-enabled pool) ERR-ORACLE-NOT-ENABLED)
        (ok (+ (mul-down (- ONE_8 (get oracle-average pool)) (try! (get-oracle-instant expiry yield-token)))
               (mul-down (get oracle-average pool) (get oracle-resilient pool))))
    )
)

;; @desc get-oracle-instant
;; @desc price-oracle that is more up to date but less resilient to manipulation
;; @param yield-token-trait; yield-token
;; @returns (response uint uint)
(define-read-only (get-oracle-instant (expiry uint) (yield-token principal))
    (ok (div-down ONE_8 (try! (get-price expiry yield-token))))
)

;; @desc create-pool
;; @restricted contract-owner
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param pool-token; pool token representing ownership of the pool
;; @param multisig-vote; DAO used by pool token holers
;; @param dx; amount of token added
;; @param dy; amount of yield-token added
;; @returns (response bool uint)
(define-public (create-pool (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (pool-token-trait <sft-trait>) (multisig-vote principal) (dx uint) (dy uint)) 
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? pools-data-map { yield-token: (contract-of yield-token-trait), expiry: expiry })) ERR-POOL-ALREADY-EXISTS)
        (let
            (
                (yield-token (contract-of yield-token-trait))            
                (pool-id (+ (var-get pool-count) u1))
                (pool-data {
                    total-supply: u0,
                    balance-token: u0,                
                    balance-yield-token: u0,
                    balance-virtual: u0,
                    fee-to-address: multisig-vote,
                    pool-token: (contract-of pool-token-trait),
                    fee-rate-yield-token: u0,
                    fee-rate-token: u0,
                    fee-rebate: u0,
                    listed: (* block-height ONE_8),
                    oracle-enabled: false,
                    oracle-average: u0,
                    oracle-resilient: u0,
                    token-trait: (contract-of token-trait)
                })
            )
        
            (map-set pools-map { pool-id: pool-id } { yield-token: yield-token, expiry: expiry })
            (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-data)
        
            (var-set pools-list (unwrap! (as-max-len? (append (var-get pools-list) pool-id) u500) ERR-TOO-MANY-POOLS))
            (var-set pool-count pool-id)

            (try! (contract-call? .alex-vault add-approved-token yield-token))
            (try! (contract-call? .alex-vault add-approved-token (contract-of token-trait)))
            (try! (contract-call? .alex-vault add-approved-token (contract-of pool-token-trait)))

            (try! (add-to-position expiry yield-token-trait token-trait pool-token-trait dx (some dy)))            
            (print { object: "pool", action: "created", data: pool-data })
            (ok true)
        )
    )
)

;; @desc buy-and-add-to-position
;; @desc helper function to buy required yield-token before adding position
;; @desc returns units of pool tokens minted, dx, dy-actual and dy-virtual added
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param pool-token; pool token representing ownership of the pool
;; @param dx; amount of token added (part of which will be used to buy yield-token)
;; @returns (response (tuple uint uint uint uint) uint)
(define-public (buy-and-add-to-position (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (pool-token-trait <sft-trait>) (dx uint) (max-dy (optional uint)))
    (let
        (
            (dy-act (get dy-act (try! (get-token-given-position expiry (contract-of yield-token-trait) dx))))
            (dx-adjusted (- dx (div-down dx (+ dx (try! (get-x-given-y expiry (contract-of yield-token-trait) dy-act))))))
            (dx-to-buy-dy-adjusted (- dx dx-adjusted))
        )
        (and (> dy-act u0) (is-ok (swap-x-for-y expiry yield-token-trait token-trait dx-to-buy-dy-adjusted none)))
        (add-to-position expiry yield-token-trait token-trait pool-token-trait dx-adjusted max-dy)
    )
)

;; @desc add-to-position
;; @desc returns units of pool tokens minted, dx, dy-actual and dy-virtual added
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param pool-token; pool token representing ownership of the pool
;; @param dx; amount of token added
;; @returns (response (tuple uint uint uint uint) uint)
(define-public (add-to-position (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (pool-token-trait <sft-trait>) (dx uint) (max-dy (optional uint)))
    (begin
        ;; dx must be greater than zero
        (asserts! (> dx u0) ERR-INVALID-LIQUIDITY)
        (let
            (
                (yield-token (contract-of yield-token-trait))
                (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
                (balance-token (get balance-token pool))            
                (balance-yield-token (get balance-yield-token pool))
                (balance-virtual (get balance-virtual pool))
                (total-supply (get total-supply pool))
                (add-data (try! (get-token-given-position expiry yield-token dx)))
                (new-supply (get token add-data))
                (new-dy-act (get dy-act add-data))
                (new-dy-vir (get dy-vir add-data))
                (pool-updated (merge pool {
                    total-supply: (+ new-supply total-supply),
                    balance-token: (+ balance-token dx),
                    balance-yield-token: (+ balance-yield-token new-dy-act),
                    balance-virtual: (+ balance-virtual new-dy-vir)   
                }))
                (sender tx-sender)
            )
            (asserts! (is-eq (get token-trait pool) (contract-of token-trait)) ERR-INVALID-TOKEN)
            (asserts! (is-eq (get pool-token pool) (contract-of pool-token-trait)) ERR-INVALID-TOKEN) 

            ;; at least one of dy must be greater than zero            
            (asserts! (or (> new-dy-act u0) (> new-dy-vir u0)) ERR-INVALID-LIQUIDITY)
            (asserts! (>= (default-to u340282366920938463463374607431768211455 max-dy) new-dy-act) ERR-EXCEEDS-MAX-SLIPPAGE)

            ;; send x to vault
            (unwrap! (contract-call? token-trait transfer-fixed dx sender .alex-vault none) ERR-TRANSFER-FAILED)
            ;; send y to vault
            (and (> new-dy-act u0) (unwrap! (contract-call? yield-token-trait transfer-fixed expiry new-dy-act sender .alex-vault) ERR-TRANSFER-FAILED))
        
            ;; mint pool token and send to tx-sender
            (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)    
            (as-contract (try! (contract-call? pool-token-trait mint-fixed expiry new-supply sender)))
            (print { object: "pool", action: "liquidity-added", data: pool-updated })
            (ok {supply: new-supply, balance-token: dx, balance-yield-token: new-dy-act, balance-virtual: new-dy-vir})
        )
    )
)    

;; @desc reduce-position
;; @desc returns dx and dy-actual due to the position
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param pool-token; pool token representing ownership of the pool
;; @param percent; percentage of pool token held to reduce
;; @returns (response (tuple uint uint) uint)
(define-public (reduce-position (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (pool-token-trait <sft-trait>) (percent uint))
    (begin
        (asserts! (<= percent ONE_8) ERR-PERCENT-GREATER-THAN-ONE)
        (let
            (
                (yield-token (contract-of yield-token-trait))
                (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
                (balance-token (get balance-token pool))
                (balance-yield-token (get balance-yield-token pool))
                (balance-virtual (get balance-virtual pool))                
                (total-supply (get total-supply pool))
                (total-shares (unwrap-panic (contract-call? pool-token-trait get-balance-fixed expiry tx-sender)))
                (shares (if (is-eq percent ONE_8) total-shares (mul-down total-shares percent)))
                (reduce-data (try! (get-position-given-burn expiry yield-token shares)))
                (dx (get dx reduce-data))
                (dy-act (get dy-act reduce-data))
                (dy-vir (get dy-vir reduce-data))
                (pool-updated (merge pool {
                    total-supply: (if (<= total-supply shares) u0 (- total-supply shares)),
                    balance-token: (if (<= balance-token dx) u0 (- balance-token dx)),
                    balance-yield-token: (if (<= balance-yield-token dy-act) u0 (- balance-yield-token dy-act)),
                    balance-virtual: (if (<= balance-virtual dy-vir) u0 (- balance-virtual dy-vir))
                    })
                )
                (sender tx-sender)
            )
            (asserts! (is-eq (get token-trait pool) (contract-of token-trait)) ERR-INVALID-TOKEN)
            (asserts! (is-eq (get pool-token pool) (contract-of pool-token-trait)) ERR-INVALID-TOKEN)

            (and (> dx u0) (as-contract (try! (contract-call? .alex-vault transfer-ft token-trait dx sender))))
            (and (> dy-act u0) (as-contract (try! (contract-call? .alex-vault transfer-sft yield-token-trait expiry dy-act sender))))

            (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)
            (as-contract (try! (contract-call? pool-token-trait burn-fixed expiry shares sender)))
            (print { object: "pool", action: "liquidity-removed", data: pool-updated })
            (ok {dx: dx, dy: dy-act})
        )    
    )    
)

;; @desc roll-position
;; @desc roll given liquidity position to another pool
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param pool-token; pool token representing ownership of the pool
;; @param percent; percentage of pool token held to reduce
;; @param yield-token-trait-to-roll; yield token to roll
;; @param pool-token-trait-to-roll; pool token representing ownership of the pool to roll to
;; @returns (response (tuple uint uint) uint)
(define-public (roll-position 
    (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (pool-token-trait <sft-trait>) (percent uint) 
    (expiry-to-roll uint))
    (let
        (
            (reduce-data (unwrap! (reduce-position expiry yield-token-trait token-trait pool-token-trait percent) (err u11111)))
            (dy-to-dx (get dx (unwrap! (swap-y-for-x expiry yield-token-trait token-trait (get dy reduce-data) none) (err u22222))))
        )
        (buy-and-add-to-position expiry-to-roll yield-token-trait token-trait pool-token-trait (+ (get dx reduce-data) dy-to-dx) none)
    )
)

;; @desc swap-x-for-y
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param dx; amount of token to swap
;; @param min-dy; optional, min amount of yield-token to receive
;; @returns (response (tuple uint uint) uint)
(define-public (swap-x-for-y (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (dx uint) (min-dy (optional uint)))
    (begin
        (asserts! (> dx u0) ERR-INVALID-LIQUIDITY)
        ;;(asserts! (> u2 u5) (err dx))
        (let
            (
                (yield-token (contract-of yield-token-trait))
                (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
                (balance-token (get balance-token pool))
                (balance-yield-token (get balance-yield-token pool))

                ;; lambda ~= 1 - fee-rate-yield-token * yield
                (yield (try! (get-yield expiry yield-token)))
                (fee-yield (mul-down yield (get fee-rate-yield-token pool)))
                (lambda (if (<= ONE_8 fee-yield) u0 (- ONE_8 fee-yield)))
                (dx-net-fees (mul-down dx lambda))
                (fee (if (<= dx dx-net-fees) u0 (- dx dx-net-fees)))
                (fee-rebate (mul-down fee (get fee-rebate pool)))

                (dy (try! (get-y-given-x expiry yield-token dx-net-fees)))

                (pool-updated
                    (merge pool
                        {
                            balance-token: (+ balance-token dx-net-fees fee-rebate),
                            balance-yield-token: (if (<= balance-yield-token dy) u0 (- balance-yield-token dy)),
                            oracle-resilient: (if (get oracle-enabled pool) (try! (get-oracle-resilient expiry yield-token)) u0)
                        }
                    )
                )
                (sender tx-sender)
            )
            (asserts! (is-eq (get token-trait pool) (contract-of token-trait)) ERR-INVALID-TOKEN)
            (asserts! (< (default-to u0 min-dy) dy) ERR-EXCEEDS-MAX-SLIPPAGE)

            (and (> dx u0) (unwrap! (contract-call? token-trait transfer-fixed dx sender .alex-vault none) ERR-TRANSFER-FAILED))
            (and (> dy u0) (as-contract (try! (contract-call? .alex-vault transfer-sft yield-token-trait expiry dy sender))))
            (as-contract (try! (contract-call? .alex-reserve-pool add-to-balance (contract-of token-trait) (- fee fee-rebate))))

            ;; post setting
            (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)
            (print { object: "pool", action: "swap-x-for-y", data: pool-updated })
            (ok {dx: dx-net-fees, dy: dy})
        )
    )
)

;; @desc swap-y-for-x
;; @param yield-token-trait; yield token
;; @param token-trait; token
;; @param dy; amount of yield token to swap
;; @param min-dx; optional, min amount of token to receive
;; @returns (response (tuple uint uint) uint)
(define-public (swap-y-for-x (expiry uint) (yield-token-trait <sft-trait>) (token-trait <ft-trait>) (dy uint) (min-dx (optional uint)))
    (begin
        (asserts! (> dy u0) ERR-INVALID-LIQUIDITY)
        (let
            (
                (yield-token (contract-of yield-token-trait))
                (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
                (balance-token (get balance-token pool))
                (balance-yield-token (get balance-yield-token pool))

                ;; lambda ~= 1 - fee-rate-token * yield
                (yield (try! (get-yield expiry yield-token)))
                (fee-yield (mul-down yield (get fee-rate-token pool)))
                (lambda (if (<= ONE_8 fee-yield) u0 (- ONE_8 fee-yield)))
                (dy-net-fees (mul-down dy lambda))
                (fee (if (<= dy dy-net-fees) u0 (- dy dy-net-fees)))
                (fee-rebate (mul-down fee (get fee-rebate pool)))

                (dx (try! (get-x-given-y expiry yield-token dy-net-fees)))

                (pool-updated
                    (merge pool
                        {
                            balance-token: (if (<= balance-token dx) u0 (- balance-token dx)),
                            balance-yield-token: (+ balance-yield-token dy-net-fees fee-rebate),
                            oracle-resilient: (if (get oracle-enabled pool) (try! (get-oracle-resilient expiry yield-token)) u0)
                        }
                    )
                )
                (sender tx-sender)
            )
            (asserts! (is-eq (get token-trait pool) (contract-of token-trait)) ERR-INVALID-TOKEN)
            (asserts! (< (default-to u0 min-dx) dx) ERR-EXCEEDS-MAX-SLIPPAGE)

            (and (> dx u0) (as-contract (try! (contract-call? .alex-vault transfer-ft token-trait dx sender))))
            (and (> dy u0) (unwrap! (contract-call? yield-token-trait transfer-fixed expiry dy sender .alex-vault) ERR-TRANSFER-FAILED))
            (as-contract (try! (contract-call? .alex-reserve-pool add-to-balance yield-token (- fee fee-rebate))))

            ;; post setting
            (map-set pools-data-map { yield-token: yield-token, expiry: expiry } pool-updated)
            (print { object: "pool", action: "swap-y-for-x", data: pool-updated })
            (ok {dx: dx, dy: dy-net-fees})
        )
    )
)

;; @desc get-fee-rebate
;; @param yield-token-trait; yield token
;; @returns (response uint uint)
(define-read-only (get-fee-rebate (expiry uint) (yield-token principal))
    (ok (get fee-rebate (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL)))
)

;; @desc set-fee-rebate
;; @restricted contract-owner
;; @param yield-token-trait; yield token
;; @param fee-rebate; new fee-rebate
;; @returns (response bool uint)
(define-public (set-fee-rebate (expiry uint) (yield-token principal) (fee-rebate uint))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map { yield-token: yield-token, expiry: expiry } (merge pool { fee-rebate: fee-rebate }))
        (ok true)
    )
)

;; @desc get-fee-rate-yield-token
;; @param yield-token-trait; yield token
;; @returns (response uint uint)
(define-read-only (get-fee-rate-yield-token (expiry uint) (yield-token principal))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (ok (get fee-rate-yield-token pool))
    )
)

;; @desc get-fee-rate-token
;; @param yield-token-trait; yield token
;; @returns (response uint uint)
(define-read-only (get-fee-rate-token (expiry uint) (yield-token principal))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (ok (get fee-rate-token pool))
    )
)

;; @desc set-fee-rate-yield-token
;; @restricted fee-to-address
;; @param yield-token-trait; yield token
;; @param fee-rate-yield-token; new fee-rate-yield-token
;; @returns (response bool uint)
(define-public (set-fee-rate-yield-token (expiry uint) (yield-token principal) (fee-rate-yield-token uint))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (asserts! (is-eq tx-sender (get fee-to-address pool)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map { yield-token: yield-token, expiry: expiry } (merge pool { fee-rate-yield-token: fee-rate-yield-token }))
        (ok true)
    
    )
)

;; @desc set-fee-rate-token
;; @restricted fee-to-address
;; @param yield-token-trait; yield token
;; @param fee-rate-token; new fee-rate-token
;; @returns (response bool uint)
(define-public (set-fee-rate-token (expiry uint) (yield-token principal) (fee-rate-token uint))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (asserts! (is-eq tx-sender (get fee-to-address pool)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map { yield-token: yield-token, expiry: expiry } (merge pool { fee-rate-token: fee-rate-token }))
        (ok true) 
    )
)

;; @desc get-fee-to-address
;; @param yield-token-trait; yield token
;; @returns (response principal uint)
(define-read-only (get-fee-to-address (expiry uint) (yield-token principal))
    (let 
        (
            (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        )
        (ok (get fee-to-address pool))
    )
)

(define-public (set-fee-to-address (expiry uint) (yield-token principal) (fee-to-address principal))
    (let 
        (
            (pool (try! (get-pool-details expiry yield-token)))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

        (map-set pools-data-map 
            { 
                yield-token: yield-token, expiry: expiry
            }
            (merge pool { fee-to-address: fee-to-address })
        )
        (ok true)     
    )
)

;; @desc units of yield token given units of token
;; @param yield-token-trait; yield token
;; @param dx; amount of token being added
;; @returns (response uint uint)
(define-read-only (get-y-given-x (expiry uint) (yield-token principal) (dx uint))
    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (normalized-expiry (try! (get-t expiry (get listed pool))))
        (dy (try! (contract-call? .yield-token-equation get-y-given-x (get balance-token pool) (+ (get balance-yield-token pool) (get balance-virtual pool)) normalized-expiry dx)))
        )
        (asserts! (> (get balance-yield-token pool) dy) ERR-DY-BIGGER-THAN-AVAILABLE)
        (ok dy)        
    );;)
)

;; @desc units of token given units of yield token
;; @param yield-token-trait; yield token
;; @param dy; amount of yield token being added
;; @returns (response uint uint)
(define-read-only (get-x-given-y (expiry uint) (yield-token principal) (dy uint))
    
    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (normalized-expiry (try! (get-t expiry (get listed pool))))
        )
        (contract-call? .yield-token-equation get-x-given-y (get balance-token pool) (+ (get balance-yield-token pool) (get balance-virtual pool)) normalized-expiry dy)
    )
)

;; @desc units of token required for a target price
;; @param yield-token-trait; yield token
;; @param price; target price
;; @returns (response uint uint)
(define-read-only (get-x-given-price (expiry uint) (yield-token principal) (price uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
        (balance-token (get balance-token pool))
        )
        (contract-call? .yield-token-equation get-x-given-price balance-token balance-yield-token normalized-expiry price)
    )
)

;; @desc units of yield token required for a target price
;; @param yield-token-trait; yield token
;; @param price; target price
;; @returns (response uint uint)
(define-read-only (get-y-given-price (expiry uint) (yield-token principal) (price uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
        (balance-token (get balance-token pool))
        )
        (contract-call? .yield-token-equation get-y-given-price balance-token balance-yield-token normalized-expiry price)
    )
)

;; @desc units of token required for a target yield
;; @param yield-token-trait; yield token
;; @param yield; target yield
;; @returns (response uint uint)
(define-read-only (get-x-given-yield (expiry uint) (yield-token principal) (yield uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
        (balance-token (get balance-token pool))
        )
        (contract-call? .yield-token-equation get-x-given-yield balance-token balance-yield-token normalized-expiry yield)
    )
)

;; @desc units of yield token required for a target yield
;; @param yield-token-trait; yield token
;; @param yield; target yield
;; @returns (response uint uint)
(define-read-only (get-y-given-yield (expiry uint) (yield-token principal) (yield uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-yield-token (+ (get balance-yield-token pool) (get balance-virtual pool)))
        (balance-token (get balance-token pool))
        )
        (contract-call? .yield-token-equation get-y-given-yield balance-token balance-yield-token normalized-expiry yield)
    )
)

;; @desc units of pool token to be minted, together with break-down of yield-token given amount of token being added
;; @param yield-token-trait; yield token
;; @param dx; amount of token added
;; @returns (response (tuple uint uint uint) uint)
(define-read-only (get-token-given-position (expiry uint) (yield-token principal) (dx uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-actual (get balance-yield-token pool))
        (balance-virtual (get balance-virtual pool))
        (balance-yield-token (+ balance-actual balance-virtual))
        (balance-token (get balance-token pool))
        (total-supply (get total-supply pool))
        (data (try! (contract-call? .yield-token-equation get-token-given-position balance-token balance-yield-token normalized-expiry total-supply dx)))
        (token (get token data))
        (dy (get dy data))
        (percent-act (if (is-eq balance-yield-token u0) u0 (div-down balance-actual balance-yield-token)))
        (dy-act (if (is-eq token dy) u0 (mul-down dy percent-act)))
        (dy-vir (if (is-eq token dy) token (if (<= dy dy-act) u0 (- dy dy-act))))
        )        
        (ok {token: token, dy-act: dy-act, dy-vir: dy-vir})
    )

)

;; @desc units of token, yield-token and yield-token (virtual) required to mint given units of pool-token
;; @param yield-token-trait; yield token
;; @param token; units of pool token to be minted
;; @returns (response (tuple uint uint uint) uint)
(define-read-only (get-position-given-mint (expiry uint) (yield-token principal) (token uint))

    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-actual (get balance-yield-token pool))
        (balance-virtual (get balance-virtual pool))
        (balance-yield-token (+ balance-actual balance-virtual))
        (balance-token (get balance-token pool))
        (total-supply (get total-supply pool))
        (data (try! (contract-call? .yield-token-equation get-position-given-mint balance-token balance-yield-token normalized-expiry total-supply token)))   
        (dx (get dx data))
        (dy (get dy data))
        (percent-act (div-down balance-actual balance-yield-token))
        (dy-act (mul-down dy percent-act))
        (dy-vir (if (<= dy dy-act) u0 (- dy dy-act)))
        )
        (ok {dx: dx, dy-act: dy-act, dy-vir: dy-vir})
    )
)

;; @desc units of token, yield-token and yield-token (virtual) to be returned after burning given units of pool-token
;; @param yield-token-trait; yield token
;; @param token; units of pool token to be burnt
;; @returns (response (tuple uint uint uint) uint)
(define-read-only (get-position-given-burn (expiry uint) (yield-token principal) (token uint))
    
    (let 
        (
        (pool (unwrap! (map-get? pools-data-map { yield-token: yield-token, expiry: expiry }) ERR-INVALID-POOL))
        (listed (get listed pool))
        (normalized-expiry (try! (get-t expiry listed)))
        (balance-actual (get balance-yield-token pool))
        (balance-virtual (get balance-virtual pool))
        (balance-yield-token (+ balance-actual balance-virtual))
        (balance-token (get balance-token pool))
        (total-supply (get total-supply pool))
        (data (try! (contract-call? .yield-token-equation get-position-given-burn balance-token balance-yield-token normalized-expiry total-supply token)))   
        (dx (get dx data))
        (dy (get dy data))
        (percent-act (div-down balance-actual balance-yield-token))
        (dy-act (mul-down dy percent-act))
        (dy-vir (if (<= dy dy-act) u0 (- dy dy-act)))
        )
        (ok {dx: dx, dy-act: dy-act, dy-vir: dy-vir})
    )
)


;; math-fixed-point
;; Fixed Point Math
;; following https://github.com/balancer-labs/balancer-monorepo/blob/master/pkg/solidity-utils/contracts/math/FixedPoint.sol

;; With 8 fixed digits you would have a maximum error of 0.5 * 10^-8 in each entry, 
;; which could aggregate to about 8 x 0.5 * 10^-8 = 4 * 10^-8 relative error 
;; (i.e. the last digit of the result may be completely lost to this error).
(define-constant MAX_POW_RELATIVE_ERROR u4) 

;; public functions
;;

;; @desc scale-up
;; @params a
;; @returns uint
(define-read-only (scale-up (a uint))
    (* a ONE_8)
)

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
            (max-error (+ u1 (mul-up raw MAX_POW_RELATIVE_ERROR)))
        )
        (if (< raw max-error)
            u0
            (- raw max-error)
        )
    )
)
;; @desc pow-up
;; @params a
;; @param b
;; @returns uint
(define-read-only (pow-up (a uint) (b uint))
    (let
        (
            (raw (unwrap-panic (pow-fixed a b)))
            (max-error (+ u1 (mul-up raw MAX_POW_RELATIVE_ERROR)))
        )
        (+ raw max-error)
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
