// lib/features/loads/dto/load_filter_dto.dart
import 'package:flutter/material.dart';
import '../load_filters.dart';

/// Pagination cursor modeled as a stable tuple to avoid ordering drift.
@immutable
class LoadCursorTuple {
  final DateTime pickupAt; // UTC
  final String id;
  const LoadCursorTuple({required this.pickupAt, required this.id});

  Map<String, dynamic> toJson() => {
        'pickup_at': pickupAt.toUtc().toIso8601String(),
        'id': id,
      };

  static LoadCursorTuple fromJson(Map<String, dynamic> json) => LoadCursorTuple(
        pickupAt: DateTime.parse(json['pickup_at'] as String).toUtc(),
        id: json['id'] as String,
      );
}

/// Filters DTO used by repositories and HTTP/RPC boundaries.
/// All time values are UTC ISO strings.
@immutable
class LoadFilterDto {
  final String? status; // draft|published|assigned|in_transit|delivered|canceled|covered
  final String? pickupFrom; // UTC ISO
  final String? pickupTo; // UTC ISO
  final String? origin;
  final String? destination;
  final String? equipment; // dry_van | reefer | flatbed | etc.
  final int? limit;
  final String? cursor; // opaque token or serialized LoadCursorTuple

  const LoadFilterDto({
    this.status,
    this.pickupFrom,
    this.pickupTo,
    this.origin,
    this.destination,
    this.equipment,
    this.limit,
    this.cursor,
  });

  Map<String, dynamic> toJson() => {
        if (status != null) 'status': status,
        if (pickupFrom != null) 'pickup_from': pickupFrom,
        if (pickupTo != null) 'pickup_to': pickupTo,
        if (origin != null) 'origin': origin,
        if (destination != null) 'destination': destination,
        if (equipment != null) 'equipment': equipment,
        if (limit != null) 'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };
}

extension LoadFiltersToDto on LoadFilters {
  /// Converts UI-centric LoadFilters (local dates) to API DTO (UTC ISO strings).
  LoadFilterDto toDto() {
    final q = toQueryUtc();
    return LoadFilterDto(
      status: q['status'] as String?,
      pickupFrom: q['pickup_from_utc'] as String?,
      pickupTo: q['pickup_to_utc'] as String?,
      origin: q['origin'] as String?,
      destination: q['destination'] as String?,
      equipment: q['equipment'] as String?,
      limit: q['limit'] as int?,
      cursor: q['cursor'] as String?,
    );
  }
}
