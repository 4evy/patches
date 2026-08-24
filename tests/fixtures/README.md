# Fixture projects

These tiny projects are deliberately boring. Each one represents a
different upstream language and has multiple ordered Git-exported
patches in its queue.

The fixture test applies every queue to a clean copy and checks each Git
patch before applying it. The patches contain real code changes, not
marker-only comments. When a compiler or interpreter is available, it
also checks the final source syntax. Missing toolchains are skipped so
the patch mechanics remain portable.

Each fixture source file carries a small MIT licensing disclaimer. The
examples stay tiny, but their patches add named helpers, change
behavior, and include a little patch-garden silliness.

The `multi-file` fixture is intentionally more involved. Its queue spans
a C source file, a header, and an implementation file. It exercises
ordered cross-file changes rather than only editing one source file.
