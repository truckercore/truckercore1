# Dependency Audit Report

Date: 2025-10-06

This report aggregates dependency vulnerabilities and update availability across detected package managers in this repository. Major upgrades are listed but batched separately with a note about potential breaking changes.

## NODE project: .\apps\web

### Vulnerabilities

| Package | Severity | ID/Source | Affected Range | Fix Available |
|---|---|---|---|---|
| debug | high | GHSA-4x49-vf9v-38px |  | Yes |

### Patch/Minor updates available

| Package | Current | Wanted | Latest | Update Type |
|---|---|---|---|---|
| @supabase/supabase-js | 2.57.2 | 2.58.0 | 2.58.0 | minor |
| @tanstack/react-query | 5.87.1 | 5.90.2 | 5.90.2 | minor |
| @testing-library/jest-dom | 6.8.0 | 6.9.1 | 6.9.1 | minor |
| lucide-react | 0.452.0 | 0.452.0 | 0.544.0 | minor |
| next-seo | 6.5.0 | 6.5.0 | 6.8.0 | minor |
| playwright | 1.55.0 | 1.55.1 | 1.55.1 | patch |
| sass | 1.92.1 | 1.93.2 | 1.93.2 | minor |
| typescript | 5.9.2 | 5.9.3 | 5.9.3 | patch |

### Major updates (batched)

The following have newer major versions which may introduce breaking changes. Consider evaluating release notes and upgrading in a dedicated branch.

| Package | Current | Latest | Note |
|---|---|---|---|
| @types/node | 20.19.13 | 24.7.0 | Potential breaking changes |
| @types/react | 18.3.24 | 19.2.0 | Potential breaking changes |
| @types/react-dom | 18.3.7 | 19.2.0 | Potential breaking changes |
| eslint | 8.57.1 | 9.37.0 | Potential breaking changes |
| eslint-config-next | 14.2.32 | 15.5.4 | Potential breaking changes |
| maplibre-gl | 3.6.2 | 5.8.0 | Potential breaking changes |
| next | 14.2.32 | 15.5.4 | Potential breaking changes |
| react | 18.3.1 | 19.2.0 | Potential breaking changes |
| react-dom | 18.3.1 | 19.2.0 | Potential breaking changes |
| recharts | 2.15.4 | 3.2.1 | Potential breaking changes |
| tailwindcss | 3.4.17 | 4.1.14 | Potential breaking changes |
| vitest | 2.1.9 | 3.2.4 | Potential breaking changes |
| zod | 3.25.76 | 4.1.11 | Potential breaking changes |
| zustand | 4.5.7 | 5.0.8 | Potential breaking changes |

## NODE project: .

### Vulnerabilities

| Package | Severity | ID/Source | Affected Range | Fix Available |
|---|---|---|---|---|
| dompurify | moderate | GHSA-vhxf-7vqr-mrjg | <3.2.4 | {"name":"jspdf","version":"3.0.3","isSemVerMajor":true} |
| jspdf | high | GHSA-w532-jxjh-hjhj | <=3.0.1 | {"name":"jspdf","version":"3.0.3","isSemVerMajor":true} |
| jspdf | high | GHSA-8mvj-3j78-4qmw | <=3.0.1 | {"name":"jspdf","version":"3.0.3","isSemVerMajor":true} |
| jspdf | high | dompurify | <=3.0.1 | {"name":"jspdf","version":"3.0.3","isSemVerMajor":true} |
| jspdf-autotable | high | jspdf | 2.0.9 - 2.1.0 || 2.3.3 - 3.8.4 | {"name":"jspdf-autotable","version":"5.0.2","isSemVerMajor":true} |
| xlsx | high | GHSA-4r6h-8v6p-xvw6 | * | No |
| xlsx | high | GHSA-5pgg-2g8v-p4x9 | * | No |

### Patch/Minor updates available

| Package | Current | Wanted | Latest | Update Type |
|---|---|---|---|---|
| @supabase/supabase-js | 2.57.2 | 2.58.0 | 2.58.0 | minor |
| ioredis | 5.8.0 | 5.8.1 | 5.8.1 | patch |
| qrcode | 1.5.3 | 1.5.3 | 1.5.4 | patch |
| ts-jest | 29.4.1 | 29.4.4 | 29.4.4 | patch |
| typescript | 5.9.2 | 5.9.3 | 5.9.3 | patch |

### Major updates (batched)

The following have newer major versions which may introduce breaking changes. Consider evaluating release notes and upgrading in a dedicated branch.

| Package | Current | Latest | Note |
|---|---|---|---|
| @json2csv/plainjs | 6.1.3 | 7.0.6 | Potential breaking changes |
| @types/jest | 29.5.14 | 30.0.0 | Potential breaking changes |
| @types/node | 20.19.17 | 24.7.0 | Potential breaking changes |
| concurrently | 8.2.2 | 9.2.1 | Potential breaking changes |
| electron | 28.3.3 | 38.2.1 | Potential breaking changes |
| electron-builder | 24.13.3 | 26.0.12 | Potential breaking changes |
| express | 4.21.2 | 5.1.0 | Potential breaking changes |
| jest | 29.7.0 | 30.2.0 | Potential breaking changes |
| jspdf | 2.5.2 | 3.0.3 | Potential breaking changes |
| jspdf-autotable | 3.8.4 | 5.0.2 | Potential breaking changes |
| next | 14.2.32 | 15.5.4 | Potential breaking changes |
| nock | 13.5.6 | 14.0.10 | Potential breaking changes |
| react | 18.2.0 | 19.2.0 | Potential breaking changes |
| react-dom | 18.2.0 | 19.2.0 | Potential breaking changes |
| react-leaflet | 4.2.1 | 5.0.0 | Potential breaking changes |
| stripe | 14.25.0 | 19.1.0 | Potential breaking changes |
| supertest | 6.3.4 | 7.1.4 | Potential breaking changes |
| uuid | 9.0.1 | 13.0.0 | Potential breaking changes |
| vitest | 2.1.9 | 3.2.4 | Potential breaking changes |
| wait-on | 7.2.0 | 9.0.1 | Potential breaking changes |
| zod | 3.25.76 | 4.1.11 | Potential breaking changes |

## NODE project: .\sdk

No vulnerabilities reported by native tooling.

No patch/minor updates available.

## DART project: .

No vulnerabilities reported by native tooling.

### Patch/Minor updates available

| Package | Current | Wanted | Latest | Update Type |
|---|---|---|---|---|
| build_config | 1.1.2 | 1.2.0 | 1.2.0 | minor |
| build_runner | 2.5.4 | 2.9.0 | 2.9.0 | minor |
| build_runner_core | 9.1.2 |  | 9.3.2 | minor |
| characters | 1.4.0 | 1.4.0 | 1.4.1 | patch |
| dart_style | 3.1.1 | 3.1.2 | 3.1.2 | patch |
| desktop_drop | 0.4.4 | 0.6.1 | 0.6.1 | minor |
| intl | 0.19.0 | 0.20.2 | 0.20.2 | minor |
| js | 0.6.7 | 0.6.7 | 0.7.2 | minor |
| json_serializable | 6.9.5 | 6.11.1 | 6.11.1 | minor |
| logger | 2.6.1 | 2.6.2 | 2.6.2 | patch |
| material_color_utilities | 0.11.1 | 0.11.1 | 0.13.0 | minor |
| meta | 1.16.0 | 1.16.0 | 1.17.0 | minor |
| mockito | 5.4.6 | 5.5.1 | 5.5.1 | minor |
| postgrest | 2.4.2 | 2.5.0 | 2.5.0 | minor |
| realtime_client | 2.5.2 | 2.5.3 | 2.5.3 | patch |
| screen_retriever | 0.1.9 | 0.2.0 | 0.2.0 | minor |
| shared_preferences_android | 2.4.12 | 2.4.14 | 2.4.14 | patch |
| source_helper | 1.3.7 | 1.3.8 | 1.3.8 | patch |
| supabase | 2.9.1 | 2.9.2 | 2.9.2 | patch |
| supabase_flutter | 2.10.1 | 2.10.2 | 2.10.2 | patch |
| test_api | 0.7.6 | 0.7.6 | 0.7.7 | patch |
| tray_manager | 0.2.4 | 0.5.1 | 0.5.1 | minor |
| url_launcher_android | 6.3.22 | 6.3.23 | 6.3.23 | patch |
| watcher | 1.1.3 | 1.1.4 | 1.1.4 | patch |
| window_manager | 0.3.9 | 0.5.1 | 0.5.1 | minor |

### Major updates (batched)

The following have newer major versions which may introduce breaking changes. Consider evaluating release notes and upgrading in a dedicated branch.

| Package | Current | Latest | Note |
|---|---|---|---|
| _fe_analyzer_shared | 85.0.0 | 89.0.0 | Potential breaking changes |
| analyzer | 7.7.1 | 8.2.0 | Potential breaking changes |
| build | 2.5.4 | 4.0.1 | Potential breaking changes |
| build_resolvers | 2.5.4 | 3.0.4 | Potential breaking changes |
| clipboard | 0.1.3 | 2.0.2 | Potential breaking changes |
| connectivity_plus | 6.1.5 | 7.0.0 | Potential breaking changes |
| device_info_plus | 10.1.2 | 12.1.0 | Potential breaking changes |
| file_picker | 8.3.7 | 10.3.3 | Potential breaking changes |
| flutter_dotenv | 5.2.1 | 6.0.0 | Potential breaking changes |
| flutter_lints | 5.0.0 | 6.0.0 | Potential breaking changes |
| flutter_map | 6.2.1 | 8.2.2 | Potential breaking changes |
| flutter_map_marker_cluster | 1.3.6 | 8.2.2 | Potential breaking changes |
| flutter_map_marker_popup | 6.1.2 | 8.1.0 | Potential breaking changes |
| flutter_riverpod | 2.6.1 | 3.0.1 | Potential breaking changes |
| flutter_secure_storage_linux | 1.2.3 | 2.0.1 | Potential breaking changes |
| flutter_secure_storage_macos | 3.1.3 | 4.0.0 | Potential breaking changes |
| flutter_secure_storage_platform_interface | 1.1.2 | 2.0.1 | Potential breaking changes |
| flutter_secure_storage_web | 1.2.1 | 2.0.0 | Potential breaking changes |
| flutter_secure_storage_windows | 3.1.2 | 4.0.0 | Potential breaking changes |
| flutter_tts | 3.8.5 | 4.2.3 | Potential breaking changes |
| freezed | 2.5.8 | 3.2.3 | Potential breaking changes |
| freezed_annotation | 2.4.4 | 3.1.0 | Potential breaking changes |
| geolocator | 11.1.0 | 14.0.2 | Potential breaking changes |
| geolocator_android | 4.6.2 | 5.0.2 | Potential breaking changes |
| geolocator_web | 3.0.0 | 4.1.3 | Potential breaking changes |
| go_router | 14.8.1 | 16.2.4 | Potential breaking changes |
| lints | 5.1.1 | 6.0.0 | Potential breaking changes |
| package_info_plus | 8.3.1 | 9.0.0 | Potential breaking changes |
| riverpod | 2.6.1 | 3.0.1 | Potential breaking changes |
| sentry | 8.14.2 | 9.6.0 | Potential breaking changes |
| sentry_flutter | 8.14.2 | 9.6.0 | Potential breaking changes |
| share_plus | 10.1.4 | 12.0.0 | Potential breaking changes |
| share_plus_platform_interface | 5.0.2 | 6.1.0 | Potential breaking changes |
| source_gen | 2.0.0 | 4.0.1 | Potential breaking changes |
| speech_to_text | 6.6.0 | 7.3.0 | Potential breaking changes |
| unicode | 0.3.1 | 1.1.8 | Potential breaking changes |
| win32_registry | 1.1.5 | 2.1.0 | Potential breaking changes |

## GRADLE (Android)

Gradle project detected at ./android. Native vulnerability scanning is not configured. To enable rich reports:
- Add the Gradle Versions plugin to check available updates: https://github.com/ben-manes/gradle-versions-plugin
- Consider OWASP Dependency-Check or Gradle OWASP plugin for vulnerability IDs.

---
Next steps:
- Optionally apply patch/minor updates where tests pass.
- Investigate and remediate listed vulnerabilities (apply fixes, overrides, or pins).
- Schedule major upgrades separately.