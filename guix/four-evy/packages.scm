(define-module (four-evy packages)
  #:use-module (brew-patches)
  #:re-export (brew-patches))

;; Stable module boundary for the repository's local package.  Keeping this
;; small makes the tooling catalog independent from the package build recipe.

(define-public four-evy-patches brew-patches)
