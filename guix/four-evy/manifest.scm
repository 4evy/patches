(define-module (four-evy manifest)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix profiles)
  #:use-module (four-evy tooling))

;; Guix equivalent of the Nix development shell package set.
;; Run from the repository root with:
;;
;;     guix shell -L packaging/guix -m guix/four-evy/manifest.scm

(packages->manifest four-evy-tooling-packages)
