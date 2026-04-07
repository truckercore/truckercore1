#!/usr/bin/env bash
set -e
flutter pub get
dart format --set-exit-if-changed .
dart fix --apply
flutter analyze
