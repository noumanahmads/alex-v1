(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait vault-trait .trait-vault.vault-trait)

(define-trait flash-loan-user-trait-mod
  (
    (execute (<ft-trait> <ft-trait> (optional <ft-trait>) uint uint (optional uint) principal) (response bool uint))
  )
)