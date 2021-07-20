(impl-trait .trait-flash-loan-user-mod.flash-loan-user-trait-mod)

(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait vault-trait .trait-vault-flat.vault-trait-flat)

;; test-flash-loan-user
;; <add a description here>

;; constants
;;

;; data maps and vars
;;

;; private functions
;;

;; public functions
;;
(define-public (execute 
                    (token1 <ft-trait>) 
                    (token2 <ft-trait>) 
                    (token3 (optional <ft-trait>)) 
                    (amount1 uint) 
                    (amount2 uint) 
                    (amount3 (optional uint)) 
                    (the-vault <vault-trait>))
    (let
        
        (
            (weight1 u50000000)
            (weight2 u50000000)
        )

        ;; do whatever you want to do with the loan you have
        (asserts! (is-ok (contract-call? .fixed-weight-pool swap-x-for-y token1 token2 weight1 weight2 the-vault amount1)))

        ;; once you are done, return the loan
         (asserts! (is-ok (contract-call? token1 transfer (as-contract tx-sender) (contract-of the-vault))))
        ;; do the same for token2 and token3

        (ok true)
         
    )
)
