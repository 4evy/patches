(define-module (four-evy system)
  #:use-module (gnu)
  #:use-module (four-evy tooling)
  #:export (four-evy-system-packages
            four-evy-operating-system))

;; Guix's composition primitive is an operating-system value inheriting from
;; a base system. This is the counterpart to the NixOS/darwin modules in
;; modules/*.nix: it is opt-in and does not enable Docker.

(define* (four-evy-system-packages #:optional (extra-packages '()))
  (append four-evy-tooling-packages extra-packages))

(define* (four-evy-operating-system base #:optional (extra-packages '()))
  (operating-system
    (inherit base)
    (packages
     (append (four-evy-system-packages extra-packages)
             (operating-system-packages base)))))
