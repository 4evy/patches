(define-module (four-evy home)
  #:use-module (gnu home)
  #:use-module (four-evy tooling)
  #:export (four-evy-home-packages
            four-evy-home-environment))

;; Guix Home counterpart to modules/home-manager.nix.

(define* (four-evy-home-packages #:optional (extra-packages '()))
  (append four-evy-tooling-packages extra-packages))

(define* (four-evy-home-environment #:optional (extra-packages '()))
  (home-environment
    (packages (four-evy-home-packages extra-packages))))
