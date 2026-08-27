# Contributing

This is a personal repository for my own patches. I do not accept
contributions or pull requests here.

You are welcome to fork it, adapt it, and keep your own version. If you
think I should know about something, please use the contact form on the
site where you found this repository.

For local changes, run:

```sh
nix develop -c just check
```

Shell code is POSIX `sh`, not Bash. Standalone scripts use the `.sh`
suffix, start with `#!/bin/sh`, declare `# shellcheck shell=sh`, and
pass both ShellCheck and shfmt through `just shell-check`. GitHub
Actions run blocks also default to `sh`; keep Bash-only arrays, brace
expansion, and conditionals out of them.

Keep your fork's changes focused and update its README when a command or
workflow changes. See [PATCH-LICENSE.md](PATCH-LICENSE.md) for the
license boundary around patch files.
