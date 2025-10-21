import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight loader for truck restrictions hints from asset JSON.
/// The asset should live at assets/data/state_restrictions.json (already declared in pubspec).
/// The structure can be a map of state code -> { low_clearance: [...], restricted_routes: [...] }.
class RestrictionsService {
  RestrictionsService._();
  static final RestrictionsService instance = RestrictionsService._();

  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('data/state_restrictions.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = map;
      return map;
    } catch (_) {
      _cache = <String, dynamic>{};
      return _cache!;
    }
  }

  /// Returns simple compliance hints based on origin/destination containing state keywords.
  /// This is intentionally heuristic for MVP: real routing should compare actual polyline segments.
  Future<List<String>> hintsFor({String? origin, String? destination, bool hazmat = false}) async {
    final data = await _load();
    final text = '${origin ?? ''} ${destination ?? ''}'.toLowerCase();
    final List<String> hints = [];

    bool mentions(String codeOrName) => text.contains(codeOrName.toLowerCase());

    // Scan for some known states
    for (final stateKey in data.keys) {
      if (mentions(stateKey) || mentions(_stateName(stateKey))) {
        final st = data[stateKey] as Map<String, dynamic>?;
        if (st == null) continue;
        final lows = (st['low_clearance'] as List?)?.cast<String>() ?? const [];
        final restr = (st['restricted_routes'] as List?)?.cast<String>() ?? const [];
        if (lows.isNotEmpty) hints.add('$stateKey: Low-clearance hotspots present');
        if (restr.isNotEmpty) hints.add('$stateKey: Restricted truck routes in effect');
      }
    }

    if (hazmat) {
      // Generic hazmat reminder
      hints.add('Hazmat: verify placards/route eligibility for tunnels/parkways');
    }

    return hints;
  }

  String _stateName(String code) {
    switch (code.toUpperCase()) {
      case 'NJ':
        return 'New Jersey';
      case 'NY':
        return 'New York';
      case 'NH':
        return 'New Hampshire';
      case 'NM':
        return 'New Mexico';
      default:
        return code;
    }
  }
}
