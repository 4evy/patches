(define-module (four-evy tooling)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages check)
  #:use-module (gnu packages docker)
  #:use-module (gnu packages haskell-apps)
  #:use-module (gnu packages node)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages patchutils)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages shellutils)
  #:use-module (gnu packages version-control)
  #:use-module (four-evy packages)
  #:export (four-evy-tooling-packages
            four-evy-tooling-map
            four-evy-supported-tools
            four-evy-unsupported-tools))

;; Guix names for the tools exposed by nix/packages.nix.  Keep this list
;; explicit: a missing package must be visible during review rather than
;; disappearing from a manifest through a failed or permissive lookup.

(define-public four-evy-tooling-packages
  (list
   four-evy-patches
   actionlint
   docker-cli
   docker-compose
   direnv
   git
   just
   node
   nix
   pre-commit
   quilt
   ruby
   shellcheck
   shfmt))

(define-public four-evy-tooling-map
  '(("actionlint" . "actionlint")
    ("docker-client" . "docker-cli")
    ("docker-compose" . "docker-compose")
    ("direnv" . "direnv")
    ("git" . "git")
    ("hadolint" . #f)
    ("just" . "just")
    ("nodejs" . "node")
    ("nix" . "nix")
    ("nix-direnv" . #f)
    ("npins" . #f)
    ("pre-commit" . "pre-commit")
    ("prettier" . #f)
    ("quilt" . "quilt")
    ("ruby" . "ruby")
    ("shellcheck" . "shellcheck")
    ("shfmt" . "shfmt")
    ("typescript" . #f)))

(define-public four-evy-supported-tools
  (filter-map cdr four-evy-tooling-map))

(define-public four-evy-unsupported-tools
  (filter-map (lambda (entry)
                (and (not (cdr entry)) (car entry)))
              four-evy-tooling-map))
