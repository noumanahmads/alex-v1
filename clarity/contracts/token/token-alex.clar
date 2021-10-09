(impl-trait .trait-ownable.ownable-trait)
(impl-trait .trait-sip-010.sip-010-trait)
(impl-trait .token-alex-trait.trait-token-alex)
(use-trait coreTrait .token-alex-core-trait.trait-token-alex-core)

(define-fungible-token alex)

(define-data-var token-uri (string-utf8 256) u"")
(define-data-var contract-owner principal tx-sender)

;; errors
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR_TOKEN_NOT_ACTIVATED (err u8001))
(define-constant ERR_TOKEN_ALREADY_ACTIVATED (err u8002))

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-public (set-owner (owner principal))
  (begin
    (asserts! (is-eq contract-caller (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner owner))
  )
)

;; ---------------------------------------------------------
;; SIP-10 Functions
;; ---------------------------------------------------------

(define-read-only (get-total-supply)
  (ok (decimals-to-fixed (ft-get-supply alex)))
)

(define-read-only (get-name)
  (ok "ALEX")
)

(define-read-only (get-symbol)
  (ok "ALEX")
)

(define-read-only (get-decimals)
  (ok u0)
)

(define-read-only (get-balance (account principal))
  (ok (decimals-to-fixed (ft-get-balance alex account)))
)

(define-public (set-token-uri (value (string-utf8 256)))
  (begin
    (asserts! (is-eq contract-caller (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set token-uri value))
  )
)

(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

(define-constant ONE_8 (pow u10 u8))

(define-private (pow-decimals)
  (pow u10 (unwrap-panic (get-decimals)))
)

(define-read-only (fixed-to-decimals (amount uint))
  (/ (* amount (pow-decimals)) ONE_8)
)

(define-private (decimals-to-fixed (amount uint))
  (/ (* amount ONE_8) (pow-decimals))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq sender tx-sender) ERR-NOT-AUTHORIZED)
    (match (ft-transfer? alex (fixed-to-decimals amount) sender recipient)
      response (begin
        (print memo)
        (ok response)
      )
      error (err error)
    )
  )
)

;; TOKEN CONFIGURATION

;; how many blocks until the next halving occurs
(define-constant TOKEN_HALVING_BLOCKS u210000)

;; store block height at each halving, set by register-user in core contract 
(define-data-var coinbaseThreshold1 uint u0)
(define-data-var coinbaseThreshold2 uint u0)
(define-data-var coinbaseThreshold3 uint u0)
(define-data-var coinbaseThreshold4 uint u0)
(define-data-var coinbaseThreshold5 uint u0)

;; once activated, thresholds cannot be updated again
(define-data-var tokenActivated bool false)

;; core contract states
(define-constant STATE_DEPLOYED u0)
(define-constant STATE_ACTIVE u1)
(define-constant STATE_INACTIVE u2)

;; one-time function to activate the token
(define-public (activate-token (coreContract principal) (stacksHeight uint))
  (let
    (
      (coreContractMap (try! (contract-call? .token-alex-auth get-core-contract-info coreContract)))
    )
    (asserts! (is-eq (get state coreContractMap) STATE_ACTIVE) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get tokenActivated)) ERR_TOKEN_ALREADY_ACTIVATED)
    (var-set tokenActivated true)
    (var-set coinbaseThreshold1 (+ stacksHeight TOKEN_HALVING_BLOCKS))
    (var-set coinbaseThreshold2 (+ stacksHeight (* u2 TOKEN_HALVING_BLOCKS)))
    (var-set coinbaseThreshold3 (+ stacksHeight (* u3 TOKEN_HALVING_BLOCKS)))
    (var-set coinbaseThreshold4 (+ stacksHeight (* u4 TOKEN_HALVING_BLOCKS)))
    (var-set coinbaseThreshold5 (+ stacksHeight (* u5 TOKEN_HALVING_BLOCKS)))
    (ok true)
  )
)

;; return coinbase thresholds if token activated
(define-read-only (get-coinbase-thresholds)
  (let
    (
      (activated (var-get tokenActivated))
    )
    (asserts! activated ERR_TOKEN_NOT_ACTIVATED)
    (ok {
      coinbaseThreshold1: (var-get coinbaseThreshold1),
      coinbaseThreshold2: (var-get coinbaseThreshold2),
      coinbaseThreshold3: (var-get coinbaseThreshold3),
      coinbaseThreshold4: (var-get coinbaseThreshold4),
      coinbaseThreshold5: (var-get coinbaseThreshold5)
    })
  )
)

;; mint new tokens, only accessible by a Core contract
(define-public (mint (recipient principal) (amount uint))
  (let
    (
      (coreContract (try! (contract-call? .token-alex-auth get-core-contract-info contract-caller)))
    )
    (ft-mint? alex amount recipient)
  )
)

;; burn tokens, only accessible by a Core contract
(define-public (burn (recipient principal) (amount uint))
  (let
    (
      (coreContract (try! (contract-call? .token-alex-auth get-core-contract-info contract-caller)))
    )
    (ft-burn? alex amount recipient)
  )
)

;; checks if caller is Auth contract
(define-private (is-authorized-auth)
  (is-eq contract-caller .token-alex-auth)
)

;; SEND-MANY

(define-public (send-many (recipients (list 200 { to: principal, amount: uint, memo: (optional (buff 34)) })))
  (fold check-err
    (map send-token recipients)
    (ok true)
  )
)

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result
               err-value (err err-value)
  )
)

(define-private (send-token (recipient { to: principal, amount: uint, memo: (optional (buff 34)) }))
  (send-token-with-memo (get amount recipient) (get to recipient) (get memo recipient))
)

(define-private (send-token-with-memo (amount uint) (to principal) (memo (optional (buff 34))))
  (let
    (
      (transferOk (try! (transfer amount tx-sender to memo)))
    )
    (ok transferOk)
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FUNCTIONS ONLY USED DURING TESTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (test-mint (amount uint) (recipient principal))
  (ft-mint? alex amount recipient)
)

(define-public (test-set-token-activation)
  (ok (var-set tokenActivated true))
)


;; Initialize the contract for Testing.
(begin
  (try! (ft-mint? alex u10000 tx-sender))
)
