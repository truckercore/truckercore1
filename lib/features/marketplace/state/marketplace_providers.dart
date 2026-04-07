// lib/features/marketplace/state/marketplace_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/config/app_config.dart';

/// Centralized providers for Marketplace feature
/// Keep tokens/IDs behind providers and guard missing values clearly.

/// Public API base URL for the marketplace (reuse an existing config field if applicable).
final marketplaceApiBaseUrlProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final url = cfg.trimbleBaseUrl; // Using trimbleBaseUrl as an example backend URL
  if (url.isEmpty) {
    if (cfg.useMockData) {
      // In mock mode we return an empty string/sentinel so UI can render placeholders
      return '';
    }
    throw StateError('Marketplace API base URL is not configured');
  }
  return url;
});

/// Optional API token for marketplace integrations if you use one later.
final marketplaceApiTokenProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  // If you later add a token to AppConfig, read it here. For now, derive from mapboxToken to show pattern.
  final token = cfg.mapboxToken; // placeholder to keep tokens behind providers
  if (token.isEmpty) {
    if (cfg.useMockData) return '';
    throw StateError('Marketplace API token is not configured');
  }
  return token;
});

/// Simple filter state for marketplace board (search text, onlyOpen, sort, etc.)
class MarketplaceFilters {
  final String query;
  final bool onlyOpen;
  const MarketplaceFilters({this.query = '', this.onlyOpen = true});

  MarketplaceFilters copyWith({String? query, bool? onlyOpen}) => MarketplaceFilters(
        query: query ?? this.query,
        onlyOpen: onlyOpen ?? this.onlyOpen,
      );
}

final marketplaceFiltersProvider = StateProvider<MarketplaceFilters>((ref) => const MarketplaceFilters());

/// Page size provider (allows quick tuning and A/B)
final marketplacePageSizeProvider = Provider<int>((ref) => 25);

/// Debug flag to enable experimental marketplace features
final marketplaceExperimentsEnabledProvider = StateProvider<bool>((ref) => !kReleaseMode);
