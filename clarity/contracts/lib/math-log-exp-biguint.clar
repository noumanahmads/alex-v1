
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
(define-constant ONE_8 (pow 10 8))
(define-constant ONE_10 (pow 10 10))

(define-constant ONE_16 (pow 10 16))

;; The domain of natural exponentiation is bound by the word size and number of decimals used.
;; The largest possible result is (2^127 - 1) / 10^8, 
;; which makes the largest exponent ln((2^127 - 1) / 10^8) = 69.6090111872.
;; The smallest possible result is 10^(-8), which makes largest negative argument ln(10^(-8)) = -18.420680744.
;; We use 69.0 and -18.0 to have some safety margin.
(define-constant MAX_NATURAL_EXPONENT (* 51 ONE_16))
(define-constant MIN_NATURAL_EXPONENT (* -36 ONE_16))

(define-constant MILD_EXPONENT_BOUND (/ (pow u2 u126) (to-uint ONE_16)))

;; Because largest exponent is 69, we start from 64
;; The first several a_n are too large if stored as 8 decimal numbers, and could cause intermediate overflows.
;; Instead we store them as plain integers, with 0 decimals.

;; a_pre is in scientific notation
;; a_n can all be stored in 16 decimal place

;; 16 decimal constants
(define-constant x_a_list (list 
{x_pre: 320000000000000000, a_pre: 789629601826806951609780226351, a_exp: -16} ;; x0 = 2^5, a0 = e^(x0)
{x_pre: 160000000000000000, a_pre: 88861105205078726367630, a_exp: -16} ;; x1 = 2^4, a1 = e^(x1)
{x_pre: 80000000000000000, a_pre: 29809579870417282747, a_exp: -16} ;; x2 = 2^3, a2 = e^(x2)
{x_pre: 40000000000000000, a_pre: 545981500331442391, a_exp: -16} ;; x3 = 2^2, a3 = e^(x3)
{x_pre: 20000000000000000, a_pre: 73890560989306502, a_exp: -16} ;; x4 = 2^1, a4 = e^(x4)
{x_pre: 10000000000000000, a_pre: 27182818284590452, a_exp: -16} ;; x5 = 2^0, a5 = e^(x5)
{x_pre: 5000000000000000, a_pre: 16487212707001282, a_exp: -16} ;; x6 = 2^-1, a6 = e^(x6)
{x_pre: 2500000000000000, a_pre: 12840254166877415, a_exp: -16} ;; x7 = 2^-2, a7 = e^(x7)
{x_pre: 1250000000000000, a_pre: 11331484530668263, a_exp: -16} ;; x8 = 2^-3, a8 = e^(x8)
{x_pre: 625000000000000, a_pre: 10644944589178594, a_exp: -16} ;; x9 = 2^-4, a9 = e^(x9)
{x_pre: 312500000000000, a_pre: 10317434074991027, a_exp: -16} ;; x10 = 2^-5, a10 = e^(x10)
))


(define-constant ERR-X-OUT-OF-BOUNDS (err u5009))
(define-constant ERR-Y-OUT-OF-BOUNDS (err u5010))
(define-constant ERR-PRODUCT-OUT-OF-BOUNDS (err u5011))
(define-constant ERR-INVALID-EXPONENT (err u5012))
(define-constant ERR-OUT-OF-BOUNDS (err u5013))

(define-read-only (scale-up (a int))
    (* a ONE_16)
)

(define-read-only (scale-down (a int))
    (/ a ONE_16)
)

;; private functions
;;

;; ;; Internal natural logarithm (ln(a)) with signed 8 decimal fixed point argument.
;; (define-public (ln-priv (a int))
;;   (let
;;     (
;;       (a_sum (fold accumulate_division x_a_list {a: a, sum: 0}))
;;       (out_a (get a a_sum))
;;       (out_sum (get sum a_sum))
;;       (z (/ (scale-up (- out_a ONE_8)) (+ out_a ONE_8))) ;; this is scaling up for division precision
;;       (z_squared (scale-down (* z z)))
;;       (div_list (list 3 5 7 9 11))
;;       (num_sum_zsq (fold rolling_sum_div div_list {num: z, seriesSum: z, z_squared: z_squared}))
;;       (seriesSum (get seriesSum num_sum_zsq))
;;       (r (+ out_sum (* seriesSum 2)))
;;    )
;;     ;; (ok r)
;;     (ok {a_sum: a_sum, z: z, z_squared: z_squared})
;;  )
;; )

(define-private (ln-priv (a int))
    (let
        (
            ;; decomposition process
            ;; https://github.com/balancer-labs/balancer-v2-monorepo/blob/a62e10f948c5de65ddfd6d07f54818bf82379eea/pkg/solidity-utils/contracts/math/LogExpMath.sol#L349
            (a_sum (fold accumulate_division x_a_list {a: a, sum: 0}))
            (out_a (get a a_sum))
            (out_sum (get sum a_sum))
            ;; below is the Taylor series now 
            ;; https://github.com/balancer-labs/balancer-v2-monorepo/blob/a62e10f948c5de65ddfd6d07f54818bf82379eea/pkg/solidity-utils/contracts/math/LogExpMath.sol#L416 
            ;; z = (a-1)/(a+1) so for precision we multiply dividend with ONE_16 to retain precision
            (z (/ (scale-up (- out_a ONE_16)) (+ out_a ONE_16)))
            (z_squared (/ (* z z) ONE_16))
            (div_list (list 3 5 7 9 11))
            (num_sum_zsq (fold rolling_sum_div div_list {num: z, seriesSum: z, z_squared: z_squared}))
            (seriesSum (get seriesSum num_sum_zsq))
            (r (+ out_sum (* seriesSum 2)))
        )
        ;; (ok {a_sum: a_sum, z: z, z_squared: z_squared})
        (ok r)
    )
)

(define-private (accumulate_division (x_a_pre (tuple (x_pre int) (a_pre int) (a_exp int))) (rolling_a_sum (tuple (a int) (sum int))))
  (let
    (
      (a_pre (get a_pre x_a_pre))
      (x_pre (get x_pre x_a_pre))
      (rolling_a (get a rolling_a_sum))
      (rolling_sum (get sum rolling_a_sum))
   )
   ;; I think we can simply use a_pre without scaling here
   ;; https://github.com/balancer-labs/balancer-v2-monorepo/blob/a62e10f948c5de65ddfd6d07f54818bf82379eea/pkg/solidity-utils/contracts/math/LogExpMath.sol#L347
    (if (>= rolling_a a_pre) 
      {a: (/ (* rolling_a ONE_16) a_pre), sum: (+ rolling_sum x_pre)} ;; rolling_a is scaled up so that precision is not lost when dividing by a_pre
      {a: rolling_a, sum: rolling_sum}
   )
 )
)

(define-private (rolling_sum_div (n int) (rolling (tuple (num int) (seriesSum int) (z_squared int))))
  (let
    (
      (rolling_num (get num rolling))
      (rolling_sum (get seriesSum rolling))
      (z_squared (get z_squared rolling))
      (next_num (scale-down (* rolling_num z_squared)))
      (next_sum (+ rolling_sum (/ next_num n)))
   )
    {num: next_num, seriesSum: next_sum, z_squared: z_squared}
 )
)

;; ;; Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
;; ;; arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
;; ;; x^y = exp(y * ln(x)).
;; ;; Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
;; (define-read-only (pow-priv (x uint) (y uint))
;;   (let
;;     (
;;       (x-int (to-int x))
;;       (y-int (to-int y))
;;       (lnx (unwrap-panic (ln-priv x-int)))
;;       (logx-times-y (scale-down (* lnx y-int)))
;;     )
;;     (asserts! (and (<= MIN_NATURAL_EXPONENT logx-times-y) (<= logx-times-y MAX_NATURAL_EXPONENT)) ERR-PRODUCT-OUT-OF-BOUNDS)
;;     (ok (to-uint (unwrap-panic (exp-fixed logx-times-y))))
;;   )
;; )

;; (define-read-only (exp-pos (x int))
;;   (begin
;;     (asserts! (and (<= 0 x) (<= x MAX_NATURAL_EXPONENT)) (err ERR-INVALID-EXPONENT))
;;     (let
;;       (
;;         ;; For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
;;         ;; it and compute the accumulated product.
;;         (x_product_no_deci (fold accumulate_product x_a_list_no_deci {x: x, product: 1}))
;;         (x_adj (get x x_product_no_deci))
;;         (firstAN (get product x_product_no_deci))
;;         (x_product (fold accumulate_product x_a_list {x: x_adj, product: ONE_8}))
;;         ;; (x_product (fold accumulate_product x_a_list {x: x, product: 1}))
;;         (product_out (get product x_product))
;;         (x_out (get x x_product))
;;         (seriesSum (+ ONE_8 x_out))
;;         (div_list (list 2 3 4 5 6 7 8 9 10 11 12))
;;         (term_sum_x (fold rolling_div_sum div_list {term: x_out, seriesSum: seriesSum, x: x_out}))
;;         (sum (get seriesSum term_sum_x))
;;      )
;;       (ok (* (scale-down (* product_out sum)) firstAN))
;;    )
;;  )
;; )

;; (define-private (accumulate_product (x_a_pre (tuple (x_pre int) (a_pre int) (use_deci bool))) (rolling_x_p (tuple (x int) (product int))))
;;   (let
;;     (
;;       (x_pre (get x_pre x_a_pre))
;;       (a_pre (get a_pre x_a_pre))
;;       (use_deci (get use_deci x_a_pre))
;;       (rolling_x (get x rolling_x_p))
;;       (rolling_product (get product rolling_x_p))
;;    )
;;     (if (>= rolling_x x_pre)
;;       {x: (- rolling_x x_pre), product: (/ (* rolling_product a_pre) (if use_deci ONE_8 1))}
;;       {x: rolling_x, product: rolling_product}
;;    )
;;  )
;; )

;; (define-private (rolling_div_sum (n int) (rolling (tuple (term int) (seriesSum int) (x int))))
;;   (let
;;     (
;;       (rolling_term (get term rolling))
;;       (rolling_sum (get seriesSum rolling))
;;       (x (get x rolling))
;;       (next_term (/ (scale-down (* rolling_term x)) n))
;;       (next_sum (+ rolling_sum next_term))
;;    )
;;     {term: next_term, seriesSum: next_sum, x: x}
;;  )
;; )

;; ;; public functions
;; ;;

;; (define-read-only (get-exp-bound)
;;   (ok MILD_EXPONENT_BOUND)
;; )

;; ;; Exponentiation (x^y) with unsigned 8 decimal fixed point base and exponent.
;; (define-read-only (pow-fixed (x uint) (y uint))
;;   (begin
;;     ;; The ln function takes a signed value, so we need to make sure x fits in the signed 128 bit range.
;;     (asserts! (< x (pow u2 u127)) ERR-X-OUT-OF-BOUNDS)

;;     ;; This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 128 bit range.
;;     (asserts! (< y MILD_EXPONENT_BOUND) ERR-Y-OUT-OF-BOUNDS)

;;     (if (is-eq y u0) 
;;       (ok (to-uint ONE_8))
;;       (if (is-eq x u0) 
;;         (ok u0)
;;         (pow-priv x y)
;;       )
;;     )
;;   )
;; )

;; ;; Natural exponentiation (e^x) with signed 8 decimal fixed point exponent.
;; ;; Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
;; (define-read-only (exp-fixed (x int))
;;   (begin
;;     (asserts! (and (<= MIN_NATURAL_EXPONENT x) (<= x MAX_NATURAL_EXPONENT)) (err ERR-INVALID-EXPONENT))
;;     (if (< x 0)
;;       ;; We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
;;       ;; fits in the signed 128 bit range (as it is larger than MIN_NATURAL_EXPONENT).
;;       ;; Fixed point division requires multiplying by ONE_8.
;;       (ok (/ (scale-up ONE_8) (unwrap-panic (exp-pos (* -1 x)))))
;;       (exp-pos x)
;;     )
;;   )
;; )

;; ;; Logarithm (log(arg, base), with signed 8 decimal fixed point base and argument.
;; (define-read-only (log-fixed (arg int) (base int))
;;   ;; This performs a simple base change: log(arg, base) = ln(arg) / ln(base).
;;   (let
;;     (
;;       (logBase (scale-up (unwrap-panic (ln-priv base))))
;;       (logArg (scale-up (unwrap-panic (ln-priv arg))))
;;    )
;;     (ok (/ (scale-up logArg) logBase))
;;  )
;; )

;; Natural logarithm (ln(a)) with signed 8 decimal fixed point argument.
(define-read-only (ln-fixed (a int))
  (begin
    (asserts! (> a 0) (err ERR-OUT-OF-BOUNDS))
    (if (< a ONE_16)
      ;; Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)).
      ;; If a is less than one, 1/a will be greater than one.
      ;; Fixed point division requires multiplying by ONE_8.
      (ok (- 0 (unwrap-panic (ln-priv (/ (scale-up ONE_16) a)))))
      (ln-priv a)
   )
 )
)

;; (define-constant x_a_list_no_deci_update (list 
;; {x_pre: 640000000000000000, a_pre: 62351490808116168829, use_deci: false} ;; x1 = 2^6, a1 = e^(x1)
;; ))



;; 16 decimal constants
(define-constant x_a_list_update (list 
{x_pre: 3200000000000000000000000000000000, x_pre_exp: -16, a_pre: 789629601826806951609780226351, a_exp: -16} ;; x0 = 2^5, a0 = e^(x0)
{x_pre: 1600000000000000000000000000000000, x_pre_exp: -16, a_pre: 88861105205078726367630, a_exp: -16} ;; x1 = 2^4, a1 = e^(x1)
{x_pre: 800000000000000000000000000000000, x_pre_exp: -16, a_pre: 29809579870417282747, a_exp: -16} ;; x2 = 2^3, a2 = e^(x2)
{x_pre: 400000000000000000000000000000000, x_pre_exp: -16, a_pre: 545981500331442391, a_exp: -16} ;; x3 = 2^2, a3 = e^(x3)
{x_pre: 200000000000000000000000000000000, x_pre_exp: -16, a_pre: 73890560989306502, a_exp: -16} ;; x4 = 2^1, a4 = e^(x4)
{x_pre: 100000000000000000000000000000000, x_pre_exp: -16, a_pre: 27182818284590452, a_exp: -16} ;; x5 = 2^0, a5 = e^(x5)
{x_pre: 50000000000000000000000000000000, x_pre_exp: -16, a_pre: 16487212707001282, a_exp: -16} ;; x6 = 2^-1, a6 = e^(x6)
{x_pre: 25000000000000000000000000000000, x_pre_exp: -16, a_pre: 12840254166877415, a_exp: -16} ;; x7 = 2^-2, a7 = e^(x7)
{x_pre: 12500000000000000000000000000000, x_pre_exp: -16, a_pre: 11331484530668263, a_exp: -16} ;; x8 = 2^-3, a8 = e^(x8)
{x_pre: 6250000000000000000000000000000, x_pre_exp: -16, a_pre: 10644944589178594, a_exp: -16} ;; x9 = 2^-4, a9 = e^(x9)
;; {x_pre: 312500000000000000000000000000, x_pre_exp: -16, a_pre: 10317434074991027, a_exp: -16} ;; x10 = 2^-5, a10 = e^(x10)
))

;; 16 decimal constants
(define-constant x_a_list_update_other (list 
{x_pre: 320000000000000000, x_pre_exp: 16, a_pre: 789629601826806951609780226351, a_exp: -16} ;; x0 = 2^5, a0 = e^(x0)
{x_pre: 160000000000000000, x_pre_exp: 16, a_pre: 88861105205078726367630, a_exp: -16} ;; x1 = 2^4, a1 = e^(x1)
{x_pre: 80000000000000000, x_pre_exp: 16, a_pre: 29809579870417282747, a_exp: -16} ;; x2 = 2^3, a2 = e^(x2)
{x_pre: 40000000000000000, x_pre_exp: 16, a_pre: 545981500331442391, a_exp: -16} ;; x3 = 2^2, a3 = e^(x3)
{x_pre: 20000000000000000, x_pre_exp: 16, a_pre: 73890560989306502, a_exp: -16} ;; x4 = 2^1, a4 = e^(x4)
{x_pre: 10000000000000000, x_pre_exp: 16, a_pre: 27182818284590452, a_exp: -16} ;; x5 = 2^0, a5 = e^(x5)
{x_pre: 5000000000000000, x_pre_exp: 16, a_pre: 16487212707001282, a_exp: -16} ;; x6 = 2^-1, a6 = e^(x6)
{x_pre: 2500000000000000, x_pre_exp: 16, a_pre: 12840254166877415, a_exp: -16} ;; x7 = 2^-2, a7 = e^(x7)
{x_pre: 1250000000000000, x_pre_exp: 16, a_pre: 11331484530668263, a_exp: -16} ;; x8 = 2^-3, a8 = e^(x8)
{x_pre: 625000000000000, x_pre_exp: 16, a_pre: 10644944589178594, a_exp: -16} ;; x9 = 2^-4, a9 = e^(x9)
;; {x_pre: 312500000000000000000000000000, x_pre_exp: -16, a_pre: 10317434074991027, a_exp: -16} ;; x10 = 2^-5, a10 = e^(x10)
))



;; 20 * 10 ^ 2
;;788999999999999.9 * 10 ^ -1    
(define-private (greater-than-equal-to (a int) (a_exp int) (b int) (b_exp int))
  (if (> a_exp b_exp)
      true
      (if (is-eq a_exp b_exp)
        (if (>= a b)
        true
        false)
        false)
  )
)

(define-private (greater-than-equal-to-update (a int) (a_exp int) (b int) (b_exp int))
  (if (is-eq a_exp b_exp) 
    (if (>= a b)
      true
      false
    )
    (let (
          (a_num (if (> a_exp 0)
            (* a (pow 10 a_exp))
            (/ a (pow 10 (* a_exp -1)))
          ))
          (b_num (if (> b_exp 0)
            (* b (pow 10 b_exp))
            (/ b (pow 10 (* b_exp -1)))
          ))
   
          )
        (if (>= a_num b_num)
            true
            false
        )
   ) 
  )        
)

(define-private (accumulate_division_update (x_a_pre (tuple (x_pre int) (a_pre int) (x_pre_exp int) (a_exp int))) (rolling_a_sum (tuple (a int) (a_res_exp int) (sum int) (sum_res_exp int))))  
  (let
    (
      (a_pre (get a_pre x_a_pre))
      (x_pre (get x_pre x_a_pre))
      (x_pre_exp (get x_pre_exp x_a_pre))
      (a_exp (get a_exp x_a_pre))
      (rolling_a (get a rolling_a_sum))
      (rolling_sum (get sum rolling_a_sum))
      (a_res_exp (get a_res_exp rolling_a_sum))
      (sum_res_exp (get sum_res_exp rolling_a_sum))
   )
    (if (greater-than-equal-to-update rolling_a a_res_exp a_pre a_exp)
      (let 
      ((division (div-with-scientific-notation rolling_a a_res_exp a_pre a_exp)))
      {  
        a: (get result division), 
        a_res_exp: (get exponent division),
        sum: (+ rolling_sum x_pre),
        sum_res_exp: x_pre_exp
      }   
      )
      {a: rolling_a, a_res_exp: a_res_exp, sum: rolling_sum, sum_res_exp: sum_res_exp}
   )
 )
)


(define-public (ln-priv-update (a int))
    (let
        (
            ;; decomposition process
            ;; https://github.com/balancer-labs/balancer-v2-monorepo/blob/a62e10f948c5de65ddfd6d07f54818bf82379eea/pkg/solidity-utils/contracts/math/LogExpMath.sol#L349
            (a_sum (fold accumulate_division_update x_a_list_update {a: a, a_res_exp: -16, sum: 0, sum_res_exp: 0}))
            ;; (out_a (get a a_sum))
            ;; (out_sum (get sum a_sum))
            ;; ;; below is the Taylor series now 
            ;; ;; https://github.com/balancer-labs/balancer-v2-monorepo/blob/a62e10f948c5de65ddfd6d07f54818bf82379eea/pkg/solidity-utils/contracts/math/LogExpMath.sol#L416 
            ;; ;; z = (a-1)/(a+1) so for precision we multiply dividend with ONE_16 to retain precision
            ;; (z (/ (scale-up (- out_a ONE_16)) (+ out_a ONE_16)))
            ;; (z_squared (/ (* z z) ONE_16))
            ;; (div_list (list 3 5 7 9 11))
            ;; (num_sum_zsq (fold rolling_sum_div div_list {num: z, seriesSum: z, z_squared: z_squared}))
            ;; (seriesSum (get seriesSum num_sum_zsq))
            ;; (r (+ out_sum (* seriesSum 2)))
        )
        ;; (ok {a_sum: a_sum, z: z, z_squared: z_squared})
        (ok a_sum)
    )
)

(define-read-only (div-with-scientific-notation (a int) (a-exp int) (b int) (b-exp int))
    (let
        (
            (division (/ (scale-up a) b)) ;; scale-up to get the decimal part precision
            (exponent (+ (- a-exp b-exp) -16)) ;; scale down from the exponent part
        )
        {result: division, exponent: exponent}
    )
)