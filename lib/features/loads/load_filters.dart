// lib/features/loads/load_filters.dart
import 'package:flutter/material.dart';

/// Supported load statuses
enum LoadStatus {
  draft,
  published,
  assigned,
  inTransit,
  delivered,
  canceled,
  covered,
}

LoadStatus? parseLoadStatus(String? s) {
  if (s == null) return null;
  switch (s.toLowerCase()) {
    case 'draft':
      return LoadStatus.draft;
    case 'published':
      return LoadStatus.published;
    case 'assigned':
      return LoadStatus.assigned;
    case 'in_transit':
    case 'intransit':
      return LoadStatus.inTransit;
    case 'delivered':
      return LoadStatus.delivered;
    case 'canceled':
    case 'cancelled':
      return LoadStatus.canceled;
    case 'covered':
      return LoadStatus.covered;
  }
  return null;
}

@immutable
class LoadFilters {
  final LoadStatus? status;
  /// Local date range for pickup (inclusive). If provided, both should be non-null
  final DateTime? pickupFromLocal;
  final DateTime? pickupToLocal;
  final String? origin; // city or zip (free text)
  final String? destination; // city or zip (free text)
  final String? equipment; // dry_van | reefer | flatbed | etc.
  final int? limit; // page size
  final String? cursor; // pagination cursor token

  const LoadFilters({
    this.status,
    this.pickupFromLocal,
    this.pickupToLocal,
    this.origin,
    this.destination,
    this.equipment,
    this.limit,
    this.cursor,
  });

  LoadFilters copyWith({
    LoadStatus? status,
    DateTime? pickupFromLocal,
    DateTime? pickupToLocal,
    String? origin,
    String? destination,
    String? equipment,
    int? limit,
    String? cursor,
    bool clearStatus = false,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearEquipment = false,
    bool clearWindow = false,
  }) {
    return LoadFilters(
      status: clearStatus ? null : (status ?? this.status),
      pickupFromLocal: clearWindow ? null : (pickupFromLocal ?? this.pickupFromLocal),
      pickupToLocal: clearWindow ? null : (pickupToLocal ?? this.pickupToLocal),
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      equipment: clearEquipment ? null : (equipment ?? this.equipment),
      limit: limit ?? this.limit,
      cursor: cursor ?? this.cursor,
    );
  }

  bool get hasAny => status != null || pickupFromLocal != null || pickupToLocal != null ||
      (origin != null && origin!.trim().isNotEmpty) ||
      (destination != null && destination!.trim().isNotEmpty) ||
      (equipment != null && equipment!.trim().isNotEmpty && equipment != 'any');

  /// Returns a query map suitable for a repository; pickup window is normalized to UTC
  /// day boundaries to avoid local off-by-one errors.
  Map<String, dynamic> toQueryUtc() {
    if ((pickupFromLocal == null) != (pickupToLocal == null)) {
      throw ArgumentError('Both pickupFrom and pickupTo must be set together.');
    }
    if (pickupFromLocal != null && pickupToLocal != null) {
      if (!pickupFromLocal!.isBefore(pickupToLocal!) && !isSameDate(pickupFromLocal!, pickupToLocal!)) {
        throw ArgumentError('pickupFrom must be before or equal to pickupTo');
      }
    }
    DateTime? fromUtc;
    DateTime? toUtc;
    if (pickupFromLocal != null && pickupToLocal != null) {
      final r = normalizeLocalDateRangeToUtc(pickupFromLocal!, pickupToLocal!);
      fromUtc = r.start;
      toUtc = r.end;
    }
    return {
      if (status != null) 'status': statusToString(status!),
      if (fromUtc != null) 'pickup_from_utc': fromUtc.toIso8601String(),
      if (toUtc != null) 'pickup_to_utc': toUtc.toIso8601String(),
      if (origin != null && origin!.trim().isNotEmpty) 'origin': origin!.trim(),
      if (destination != null && destination!.trim().isNotEmpty) 'destination': destination!.trim(),
      if (equipment != null && equipment!.trim().isNotEmpty && equipment != 'any') 'equipment': equipment,
      if (limit != null && limit! > 0) 'limit': limit,
      if (cursor != null && cursor!.isNotEmpty) 'cursor': cursor,
    };
  }

  static String statusToString(LoadStatus s) {
    switch (s) {
      case LoadStatus.draft:
        return 'draft';
      case LoadStatus.published:
        return 'published';
      case LoadStatus.assigned:
        return 'assigned';
      case LoadStatus.inTransit:
        return 'in_transit';
      case LoadStatus.delivered:
        return 'delivered';
      case LoadStatus.canceled:
        return 'canceled';
      case LoadStatus.covered:
        return 'covered';
    }
  }
}

bool isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Normalize a local date range (dates without time-of-day) into a UTC DateTimeRange that
/// spans the entire days inclusively. This prevents off-by-one issues at day boundaries.
DateTimeRange normalizeLocalDateRangeToUtc(DateTime fromLocal, DateTime toLocal) {
  // clamp to start-of-day and end-of-day in local, then convert to UTC
  final fromStart = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
  final toEnd = DateTime(toLocal.year, toLocal.month, toLocal.day, 23, 59, 59, 999, 999);
  return DateTimeRange(start: fromStart.toUtc(), end: toEnd.toUtc());
}
