// lib/l10n/strings.dart
// Minimal EN localization for privacy/permissions copy (extensible later)
class Strings {
  final String locale;
  const Strings._(this.locale);

  static const en = Strings._('en');
  static Strings get current => en; // Placeholder: only EN for now

  // Settings / Privacy section
  String get privacyWhatWeTrackTitle => 'What we track and why';
  String get privacyWhatWeTrackSubtitle => 'Location and telemetry overview';
  String get privacyPolicyTitle => 'Privacy Policy';
  String get termsTitle => 'Terms / EULA';

  // Permission copy (store/reviewer notes can re-use)
  String get locationPermissionRationale =>
      'We use your location to power routing, compliance, and optional geofencing. Tracking occurs only when you start it, and a persistent indicator is shown.';
}
