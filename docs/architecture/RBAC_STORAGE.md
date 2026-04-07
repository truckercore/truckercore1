# RBAC, Storage Abstraction, Testing, and Documentation

This document describes the new Role-Based Access Control (RBAC) utilities and the dashboard storage abstraction added to TruckerCore, along with guidance for testing and usage.

## Overview

- RBAC centralization: a small `RbacService` consolidates role checks used by Dashboard Marketplace and routes.
- Storage abstraction: `DashboardStorage` abstracts persistence of dashboard settings/state to enable future backends (e.g., Hive, Isar, IndexedDB) without changing business logic.
- Providers refactor: dashboard preferences and user state now use the storage abstraction.
- Tests added: RBAC and storage roundtrip tests to ensure behavior is correct and portable.

---

## Role-Based Access Control (RBAC)

Files:
- lib/common/security/rbac.dart
- lib/features/dashboards/models/dashboard_metadata.dart (existing) carries `allowedRoles` per dashboard

`RbacService` API:
- `hasRole(AppRole current, AppRole role)`
- `hasAnyRole(AppRole current, List<AppRole> roles)` — empty list means allow all
- `canViewDashboard({required AppRole current, required DashboardMetadata dashboard})`

Use via Riverpod provider:
```
final rbac = ref.read(rbacProvider);
final allowed = rbac.canViewDashboard(current: session.role, dashboard: metadata);
```

Notes:
- Routing guards for primary app areas (driver, fleet manager, owner-operator, broker) remain in `app_router.dart` and continue to source truth from `sessionProvider` and Supabase auth.
- Marketplace UI also filters dashboards by `allowedRoles`. `RbacService` is a centralized helper to keep checks consistent across code.

Tests:
- `test/common/security/rbac_test.dart` exercises allow/deny cases with different role lists.

---

## Storage Abstraction for Dashboards

Files:
- lib/features/dashboards/storage/dashboard_storage.dart
- lib/features/dashboards/providers/dashboard_preferences_provider.dart (refactored)
- lib/features/dashboards/providers/dashboard_user_state.dart (refactored)

Interface:
```
abstract class DashboardStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}
```

Default implementation:
- `SharedPrefsDashboardStorage` backed by `shared_preferences` (same behavior as before, just centralized).
- Provider: `dashboardStorageProvider` to inject and override in tests/platform variants.

Refactored providers:
- `DashboardPreferencesNotifier` now depends on `DashboardStorage` instead of calling `SharedPreferences.getInstance()` directly.
- `DashboardUserStateNotifier` likewise uses `DashboardStorage` for favorites, recents, and collections.

Why this matters:
- Easier to migrate to another persistence layer (Hive/Isar/secure store/IndexedDB) by swapping the provider.
- Simplifies testing using in-memory or mocked storage.

Tests:
- `test/features/dashboards/storage/dashboard_storage_test.dart` — validates set/get/remove string and string-list using `SharedPreferences.setMockInitialValues({})`.

---

## How to Extend

### Add a new storage backend
1. Implement `DashboardStorage` (e.g., `HiveDashboardStorage`).
2. Provide it via Riverpod at the app root or in a specific scope:
```
ProviderScope(
  overrides: [
    dashboardStorageProvider.overrideWithValue(HiveDashboardStorage()),
  ],
  child: TruckerCoreApp(),
)
```

### Use RBAC in new features
- Add `allowedRoles` to any new dashboard’s metadata.
- Use `rbacProvider` to enforce view/open permissions in UI or services.

---

## Testing Guidance

Run all Flutter tests:
```
flutter test
```

Key tests added:
- `rbac_test.dart` — verifies allow/deny rules.
- `dashboard_storage_test.dart` — verifies storage setters/getters and remove.

You can also add tests that override the storage provider with an in-memory fake for speed and determinism.

Example in a test:
```
final container = ProviderContainer(overrides: [
  dashboardStorageProvider.overrideWithValue(_InMemoryStorage()),
]);
```

---

## Migration Notes

- Existing persisted preferences and user state remain compatible: the abstraction still uses `shared_preferences` so no data loss.
- UI behavior remains unchanged; only internal wiring has been refactored.

---

## Future Work

- Implement a Hive/Isar-backed `DashboardStorage` for richer querying/offline scenarios.
- Expand `RbacService` to include action-level permissions (view/edit/share) if needed.
- Add integration tests covering multi-window scenarios with storage persistence.
