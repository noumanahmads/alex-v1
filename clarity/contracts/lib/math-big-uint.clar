
(define-constant ONE_16 (pow u10 u16)) ;; 16 decimal places
(define-constant MAX_POW_RELATIVE_ERROR u8)

;; The maximum digits clarity can give in uint is 39 digits, otherwise it overflows
(define-read-only (maximum-integer (a uint) (b uint))
    (* a b)
)

(define-read-only (mul (a uint) (b uint))
    (* (scale-up a) b)
)

;; decimal says how many decimals are there in a and b together
(define-read-only (mul-16 (a uint) (a-decimals uint) (b uint) (b-decimals uint))
    (let
        (
            (result (* a b)) ;; 50*5 is actually 5 * 0.5
            (decimals (- a-decimals b-decimals))
        )
        {result: result, decimals: decimals}
    )
)

;; 2.5*4 = 10

;; 2.5 * 4
;; 25*10^-1 * 4*10^0
;; (25*4) * (10^-1 * 10^0)
;; (100) * (10^(-1+0))
;; 100 * 10^-1
;; 10

;; (25*10^-1) * (4*10^0) = 100*10^-1 = 10
;; base is 10
;; The answer from multiplication is in scaled-down form
(define-read-only (mul-with-scientific-notation (a uint) (a-exp int) (b uint) (b-exp int))
    (let
        (
            (product (* a b)) ;; 25*4=100
            (exponent (+ a-exp b-exp)) ;;10^-1 + 10^0 = 10^(-1+0) = 10^-1
        )
        {result: product, exponent: exponent} ;;100*10^-1
    )
)

;; 2.5 / 4 = 0.625
;; (25*10^-1) / (4*10^0)
;; (25/4) * (10^(-1-0))
;; (625*10^14) * (10^-1 * 10^-16)
;; (62500000000000000) * (10^-17)
;; (0.625)

;; The decimal part is ignored because system doesn't have floating points so integer division is happenning
(define-read-only (div-with-scientific-notation (a uint) (a-exp int) (b uint) (b-exp int))
    (let
        (
            (division (/ (scale-up a) b)) ;; scale-up to get the decimal part precision
            (exponent (+ (- a-exp b-exp) -16)) ;; scale down from the exponent part
        )
        {result: division, exponent: exponent}
    )
)

;; we reduced a and b so that it won't overflow
(define-read-only (div (a uint) (b uint))
    (/ (scale-up a) b)
)

(define-read-only (scale-up (a uint))
    (* a ONE_16)
)

(define-read-only (scale-down (a uint))
    (/ a ONE_16)
)

;; pow(x^y) = e^(y * ln(x))
;; ln(x) = log10(x) / log10(e^1)
;; ln(x) = log10(x) / log10(2.71828)
;; we need implementation of Exponent and Log10

;; (define-read-only (ln (a int))
;;     (unwrap-panic (contract-call? .math-log-exp-biguint ln-fixed a))
;; )

;; (define-read-only (exp (a int))
;;     (unwrap-panic (contract-call? .math-log-exp-biguint exp-fixed a))
;; )

;; (define-read-only (power (a uint) (b uint))
;;     (unwrap-panic (contract-call? .math-log-exp-biguint pow-fixed a b))
;; )