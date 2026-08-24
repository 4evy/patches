(define-module (four-evy channels)
  #:use-module (guix channels)
  #:export (four-evy-channels))

;; Nix flake inputs have no one-to-one Guix equivalent. Guix channels are the
;; corresponding source-distribution mechanism: Guix itself is the package
;; collection and system framework, while Nonguix supplies optional packages
;; that cannot be included in Guix.  Use each project's canonical URL; Guix's
;; stable project URL redirects to its Codeberg repository.

(define-public four-evy-channels
  (list
   (channel
    (inherit %default-guix-channel)
    (url "https://git.guix.gnu.org/guix.git"))
   (channel
    (name 'nonguix)
    (url "https://gitlab.com/nonguix/nonguix")
    (branch "master")
    (introduction
     (make-channel-introduction
      "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
      (openpgp-fingerprint
       "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))))
