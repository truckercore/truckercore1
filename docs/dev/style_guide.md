# TruckerCore Style Guide (Dart/Flutter)

This repo enforces a consistent code style via `analysis_options.yaml` and automated formatting.

Key rules:
- Curly braces in all control-flow structures (if/else/for/while).
- Avoid using `BuildContext` across async gaps; after any `await`, check `if (!mounted) return;` before using `context`.
- Prefer `final` and `const` when possible.
- No leading underscores for local variables (underscores are for private members).
- Prefer single quotes for strings.
- Keep imports ordered (directives_ordering).
- Avoid unused elements and fields.

Workflow:
1. Format: `dart format .`
2. Analyze: `dart analyze`
3. Fix all issues until analyzer is clean.

Pre-commit (Windows PowerShell): see `scripts/pre-commit.sample.ps1`. Copy it to `.git/hooks/pre-commit`.

Documentation:
- Add `///` doc comments to public classes and methods.
- Use `TODO:` and `FIXME:` consistently for follow-ups.

Structure:
- Use `lib/features`, `lib/common`, `lib/services`, `lib/widgets`, etc.
- Use `snake_case` for file and folder names.

Snippets/Templates:
- Create IDE snippets for common widgets (StatefulWidget/ConsumerWidget), services, and providers to ensure consistent headers and doc comments.
