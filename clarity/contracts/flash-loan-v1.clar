(impl-trait .trait-flash-loan-user-mod.flash-loan-user-trait-mod)
(use-trait ft-trait .trait-sip-010.sip-010-trait)
(use-trait vault-trait .trait-vault.vault-trait)
(define-constant insufficient-flash-loan-balance-err (err u528))
(define-constant transfer-failed-err (err u72))

(define-data-var preLoanBalance uint u0)
(define-data-var feeAmount uint u0)

(define-public (execute 
                (token1 <ft-trait>)
                (token2 <ft-trait>)
                (token3 (optional <ft-trait>))
                (amount1 uint)
                (amount2 uint)
                (amount3 (optional uint))
                (the-valut principal))
    (begin 
        ;; TODO: make sure the token and amount are provided in pairs
        (ok true)           
    )   


(define-public (flash-loan-one 
                    (token <ft-trait>) 
                    (amount uint) 
                    (recipient principal))
    (begin 
        (var-set preLoanBalance (unwrap-panic (contract-call? token get-balance tx-sender)))
        (var-set feeAmount (calculateFlashLoanFeeAmount amount))
        (print (var-get preLoanBalance))
        (print (var-get feeAmount))
        ;;TODO: make sure the preLoanBalance larger than amount else,insufficient-flash-loan-balance-err
        (asserts! (is-ok (contract-call? token transfer amount (contract-of token) tx-sender none)) transfer-failed-err)
        (ok true)
    )
)

(define-private (calculateFlashLoanFeeAmount (amount uint))
;;TODO: need to implement Flash loan fee amount, now just leave it 1%
    (/ amount u100)
)