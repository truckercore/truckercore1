// Minimal feature flags helper. Not tied to assets to avoid build changes.
// Allows local defaults and in-memory overrides for tests/dev.

class FeatureFlags {
  FeatureFlags._();

  static final Map<String, bool> _defaults = {
    'routing_v2': false,
    'saved_search_alerts': false,
    'offline_store_and_forward': true,
    'privacy_center_v1': false,
    'event_webhooks_mvp': true,
    'ifta_mvp': false,
    'ocr_pipeline_v1': false,
    'yms_light': false,
    'emissions_mvp': false,
    'delay_prediction': false,
  };

  static final Map<String, bool> _overrides = {};

  static bool isEnabled(String key) => _overrides[key] ?? _defaults[key] ?? false;

  static void setOverride(String key, bool value) {
    _overrides[key] = value;
  }

  static void clearOverrides() => _overrides.clear();

  static Map<String, bool> snapshot() => {..._defaults, ..._overrides};
}
