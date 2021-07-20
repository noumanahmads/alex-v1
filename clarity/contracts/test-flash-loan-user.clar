(impl-trait .trait-flash-loan-user-mod.flash-loan-user-trait-mod)
(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait vault-trait .trait-vault-flat.vault-trait-flat)

(define-constant insufficient-flash-loan-balance-err (err u528))
(define-constant invalid-post-loan-balance-err (err u515))
(define-constant user-execute-err (err u101))
(define-constant transfer-one-by-one-err (err u102))
(define-constant transfer-failed-err (err u72))
(define-public (execute 
                    (token1 <ft-trait>) 
                    (token2 <ft-trait>) 
                    (token3 (optional <ft-trait>)) 
                    (amount1 uint) 
                    (amount2 uint) 
                    (amount3 (optional uint)) 
                    (the-vault principal))
    (let 
        (
            (weight1 u50000000)
            (weight2 u50000000)
        )

        ;; do whatever you want to do with the loan you have
        ;; (asserts! (is-ok (contract-call? fixed-weight-pool swap-x-for-y token1 token2 weight1 weight2 the-vault amount1)))

        ;; once you are done, return the loan
        (asserts! (is-ok (contract-call? token1 transfer amount1 (as-contract tx-sender) the-vault none)) transfer-failed-err)  
        ;; do the same for token2 and token3

        (ok true)
         
    )
)
