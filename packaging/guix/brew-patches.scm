(define-module (brew-patches)
  #:use-module (gnu packages)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix licenses)
  #:use-module (guix packages))

;; Local Guix package equivalent of nix/packages.nix.  The command and stack
;; catalog are separate inputs so this stays reproducible without copying the
;; whole checkout (or the local Guix source mirror) into the build input.

(define %repository-root
  (canonicalize-path
   (string-append (dirname (search-path %load-path "brew-patches.scm"))
                  "/../..")))

(define (repository-file file)
  (string-append %repository-root "/" file))

(define-public brew-patches
  (package
    (name "brew-patches")
    (version "0.0.0-git")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils)
                       (ice-9 rdelim))
          (let* ((out (assoc-ref %outputs "out"))
                 (bash (assoc-ref %build-inputs "bash-minimal"))
                 (ruby (assoc-ref %build-inputs "ruby"))
                 (git (assoc-ref %build-inputs "git-minimal"))
                 (command (assoc-ref %build-inputs "command"))
                 (stacks (assoc-ref %build-inputs "stacks"))
                 (test-stack (assoc-ref %build-inputs "test-stack"))
                 (share (string-append out "/share/4evy-patches"))
                 (wrapper (string-append out "/bin/brew-patches"))
                 (test-stacks (string-append (getcwd) "/test-stacks"))
                 (test-source (string-append (getcwd) "/test-source")))
            (mkdir-p (dirname wrapper))
            (mkdir-p share)
            (copy-file command (string-append share "/brew-patches"))
            (copy-recursively stacks (string-append share "/stacks"))
            (call-with-output-file wrapper
              (lambda (port)
                (format port
                        (string-append "#!~a/bin/sh~%"
                                       "export PATH=~s~%"
                                       "unset GEM_HOME GEM_PATH RUBYLIB RUBYOPT~%"
                                       "export PATCHES_STACKS=~a~%"
                                       "exec ~a/bin/ruby --disable-gems ~s \"$@\"~%")
                        bash
                        (string-append git "/bin")
                        (string-append "${PATCHES_STACKS:-"
                                       share "/stacks}")
                        ruby
                        (string-append share "/brew-patches"))))
            (chmod wrapper #o755)

            ;; Exercise the installed entry point and its packaged Git runtime
            ;; against a real multi-patch fixture during every Guix build.
            (setenv "GEM_HOME" "/does-not-exist")
            (setenv "GEM_PATH" "/does-not-exist")
            (setenv "RUBYLIB" "/does-not-exist")
            (setenv "RUBYOPT" "-w")
            (invoke wrapper "validate" "ghostty")
            (mkdir-p test-stacks)
            (copy-recursively test-stack (string-append test-stacks "/demo"))
            (copy-recursively (string-append test-stack "/upstream")
                              test-source)
            (setenv "PATCHES_STACKS" test-stacks)
            (invoke wrapper "validate" "demo")
            (invoke wrapper "check" "demo" test-source)
            (invoke wrapper "apply" "demo" test-source)
            (unless
                (call-with-input-file (string-append test-source "/main.c")
                  (lambda (port)
                    (let loop ((line (read-line port)))
                      (and (not (eof-object? line))
                           (or (string-contains line "extra_value")
                               (loop (read-line port)))))))
              (error "brew-patches apply smoke test did not modify source"))))))
    (inputs
     `(("bash-minimal" ,(specification->package "bash-minimal"))
       ("ruby" ,(specification->package "ruby"))
       ("git-minimal" ,(specification->package "git-minimal"))
       ("command" ,(local-file (repository-file "cmd/brew-patches.rb")))
       ("stacks" ,(local-file (repository-file "stacks") #:recursive? #t))))
    (native-inputs
     `(("test-stack"
        ,(local-file (repository-file "tests/fixtures/multi-file")
                     #:recursive? #t))))
    (synopsis "Browse, validate, and apply patch stacks")
    (description
     "Install the repository's brew-patches command, complete patch-stack
catalog, and Git runtime as a self-contained Guix package.  The command can
validate stacks, check them safely against a temporary source copy, or apply
them to a requested checkout.")
    (home-page "https://github.com/4evy/patches")
    (license expat)))
