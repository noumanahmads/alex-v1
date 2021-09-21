(define-trait trait-token-alex
  (

    (activate-token (principal uint)
      (response bool uint)
    )

    (set-token-uri ((optional (string-utf8 256)))
      (response bool uint)
    )

    (mint (principal uint)
      (response bool uint)
    )

    (burn (principal uint)
      (response bool uint)
    )

    (send-many ((list 200 { to: principal, amount: uint, memo: (optional (buff 34)) }))
      (response bool uint)
    )

  )
)
