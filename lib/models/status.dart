// lib/models/status.dart

// Status enums for various entities

enum DriverStatus {
  available,
  onDuty,
  offDuty,
  driving,
  resting,
  unavailable,
}

enum LoadStatus {
  pending,
  assigned,
  inTransit,
  delivered,
  cancelled,
}

enum ExpenseStatus {
  pending,
  approved,
  rejected,
  reimbursed,
}

enum PodStatus {
  pending,
  submitted,
  verified,
}

// Extensions for display names
extension DriverStatusExtension on DriverStatus {
  String get displayName {
    switch (this) {
      case DriverStatus.available:
        return 'Available';
      case DriverStatus.onDuty:
        return 'On Duty';
      case DriverStatus.offDuty:
        return 'Off Duty';
      case DriverStatus.driving:
        return 'Driving';
      case DriverStatus.resting:
        return 'Resting';
      case DriverStatus.unavailable:
        return 'Unavailable';
    }
  }

  bool get isActive => this == DriverStatus.onDuty || this == DriverStatus.driving;
}

extension LoadStatusExtension on LoadStatus {
  String get displayName {
    switch (this) {
      case LoadStatus.pending:
        return 'Pending';
      case LoadStatus.assigned:
        return 'Assigned';
      case LoadStatus.inTransit:
        return 'In Transit';
      case LoadStatus.delivered:
        return 'Delivered';
      case LoadStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this == LoadStatus.assigned || this == LoadStatus.inTransit;
}

extension ExpenseStatusExtension on ExpenseStatus {
  String get displayName {
    switch (this) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.reimbursed:
        return 'Reimbursed';
    }
  }
}

extension PodStatusExtension on PodStatus {
  String get displayName {
    switch (this) {
      case PodStatus.pending:
        return 'Pending';
      case PodStatus.submitted:
        return 'Submitted';
      case PodStatus.verified:
        return 'Verified';
    }
  }
}
