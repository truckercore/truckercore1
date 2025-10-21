// lib/features/dispatch/state/dispatch_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized providers for Dispatch feature

/// Current dispatch view/tab (e.g., 'queue', 'map', 'drivers')
final dispatchCurrentTabProvider = StateProvider<String>((ref) => 'queue');

/// Active search/filter for loads/drivers in dispatch
class DispatchFilter {
  final String query;
  final bool onlyActive;
  const DispatchFilter({this.query = '', this.onlyActive = true});

  DispatchFilter copyWith({String? query, bool? onlyActive}) => DispatchFilter(
        query: query ?? this.query,
        onlyActive: onlyActive ?? this.onlyActive,
      );
}

final dispatchFilterProvider = StateProvider<DispatchFilter>((ref) => const DispatchFilter());

/// Selected driver id (if any) in the dispatch UI
final selectedDriverIdProvider = StateProvider<String?>((ref) => null);

/// Selected load id (if any) in the dispatch UI
final selectedLoadIdProvider = StateProvider<String?>((ref) => null);
