
;; bbtc
;; Counter example

;; constants!
(define-data-var counter int 2)

;; data maps and vars
;;

;; private functions

(define-read-only (get-counter) (ok (var-get counter)))

;; public functions
;;
(define-public (increment) 
    (begin
        (var-set counter (+ (var-get counter) 1))
        (ok (var-get counter))    
    )
)

(define-public (decrement) 
    (begin 
        (var-set counter (+ (var-get counter) 2))
        (ok (var-get counter))
    )
)
