import 'dart:convert';

/// Decoded claims of the courier access token (ADR-1617: `sub`, `phone`,
/// `branchId`, `role: COURIER`, `type: access`, TTL 12h).
///
/// The payload is read client-side only for session housekeeping (expiry
/// check, branch display). Authorization decisions stay on the server.
class CourierJwtPayload {
  const CourierJwtPayload({this.branchId, this.expiresAt});

  final String? branchId;
  final DateTime? expiresAt;

  /// True when the token carries no `exp` or it is already in the past.
  bool get isExpired =>
      expiresAt == null || !expiresAt!.isAfter(DateTime.now());

  /// Parses the payload segment of a compact JWT. Returns null for malformed
  /// tokens — the caller treats them as absent/expired credentials.
  static CourierJwtPayload? tryParse(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final json =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = json['exp'];
      return CourierJwtPayload(
        branchId: json['branchId'] as String?,
        expiresAt: exp is int
            ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            : null,
      );
    } on FormatException {
      return null;
    }
  }
}
