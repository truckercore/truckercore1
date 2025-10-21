# CI recommendations

In your CI pipeline (e.g., GitHub Actions, GitLab CI), enforce formatting and analysis:

- Run: `dart format --set-exit-if-changed .`
- Run: `dart analyze`

Fail the build if either command exits non-zero.

Example GitHub Actions job:

```yaml
name: Dart CI
on: [pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart --version
      - run: dart pub get
      - run: dart format --set-exit-if-changed .
      - run: dart analyze
```
