/// Minimal user roles/types representation for TruckerCore.
/// Keep in sync with server-side allowed roles.
library;

enum UserRole { driver, ownerOp, operator, admin }

extension UserRoleX on UserRole {
  String get value => switch (this) {
        UserRole.driver => 'driver',
        UserRole.ownerOp => 'owner_op',
        UserRole.operator => 'operator',
        UserRole.admin => 'admin',
      };

  static UserRole? from(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'driver':
        return UserRole.driver;
      case 'owner_op':
      case 'owner-operator':
      case 'owneroperator':
        return UserRole.ownerOp;
      case 'operator':
        return UserRole.operator;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }
}

class Roles {
  final List<UserRole> roles;
  const Roles(this.roles);

  bool get isAdmin => roles.contains(UserRole.admin);
  bool get isOperator => roles.contains(UserRole.operator);
  bool get isDriver => roles.contains(UserRole.driver);
  bool get isOwnerOp => roles.contains(UserRole.ownerOp);

  factory Roles.fromJwtClaims(Map<String, dynamic> claims) {
    final raw = claims['app_roles'];
    if (raw is List) {
      final rs = raw
          .map((e) => UserRoleX.from(e?.toString()))
          .whereType<UserRole>()
          .toList();
      return Roles(rs);
    }
    final primary = UserRoleX.from(claims['app_primary_role']?.toString());
    return Roles(primary == null ? const [] : [primary]);
  }

  Map<String, dynamic> toJson() => {
        'roles': roles.map((r) => r.value).toList(),
      };
}
