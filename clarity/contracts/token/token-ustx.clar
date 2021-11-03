(impl-trait .trait-ownable.ownable-trait)
(impl-trait .trait-pool-token.pool-token-trait)

(define-fungible-token ustx)

(define-data-var token-uri (string-utf8 256) u"")
(define-data-var contract-owner principal tx-sender)

;; errors
(define-constant ERR-NOT-AUTHORIZED (err u1000))

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
  (ok (decimals-to-fixed (ft-get-supply ustx)))
)

(define-read-only (get-name)
  (ok "USTX")
)

(define-read-only (get-symbol)
  (ok "USTX")
)

(define-read-only (get-decimals)
  (ok u0)
)

(define-read-only (get-balance (account principal))
  (ok (decimals-to-fixed (ft-get-balance ustx account)))
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
    (match (ft-transfer? ustx (fixed-to-decimals amount) sender recipient)
      response (begin
        (print memo)
        (ok response)
      )
      error (err error)
    )
  )
)

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (try! (ft-mint? ustx (fixed-to-decimals amount) recipient))
    (stx-transfer? amount recipient (as-contract tx-sender))
  )
)

(define-public (burn (sender principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (try! (ft-burn? ustx (fixed-to-decimals amount) sender))
    (as-contract (stx-transfer? amount tx-sender sender))
  )
)

;; Initialize the contract for Testing.
(begin
  (try! (ft-mint? ustx u10000 tx-sender))
)

;; (contract-call? .token-ustx mint 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u100000000000)
;; (contract-call? .token-ustx mint 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u200000000000)
;; (contract-call? .token-ustx burn 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u200000000000)
;; (contract-call? .token-ustx burn 'ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE u100000000000)
