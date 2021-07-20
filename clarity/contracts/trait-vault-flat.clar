(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait flash-loan-user-trait-mod .trait-flash-loan-user-mod.flash-loan-user-trait-mod)

;; Fungible Token SIP-010
;; TODO : Define all the error types in implementation file

(define-trait vault-trait-flat
    (   
        ;; returns the balance of token
        (get-balance (<ft-trait>) (response uint uint))

        ;; returns list of {token, balance}
        (get-balances () (response (list 2000 {token: (string-ascii 32), balance: uint}) uint))

        ;; flash loan to flash loan user up to 3 tokens of amounts specified
        (flash-loan-flat (<flash-loan-user-trait-mod> <ft-trait> <ft-trait> (optional <ft-trait>) uint uint (optional uint)) (response bool uint))
   )
)
