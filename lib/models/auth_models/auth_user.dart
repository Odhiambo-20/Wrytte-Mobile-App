class AuthUser {
  final String userId;
  final String username;
  final String secret;
  final String? token;
  final DateTime? expiresAt;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.secret,
    this.token,
    this.expiresAt,
  });

  // EMPTY USER

  const AuthUser.empty()
    : userId = '',
      username = '',
      secret = '',
      token = null,
      expiresAt = null;

  // FROM JSON

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
      token: json['token']?.toString(),
      expiresAt:
          json['expiration'] != null
              ? DateTime.tryParse(json['expiration'].toString())
              : null,
    );
  }

  // TO JSON

  Map<String, dynamic> toJson() {
    return {
      "userid": userId,
      "username": username,
      "secret": secret,
      "token": token,
      if (expiresAt != null) "expiration": expiresAt!.toUtc().toIso8601String(),
    };
  }

  // COPY WITH

  AuthUser copyWith({
    String? userId,
    String? username,
    String? secret,
    String? token,
    DateTime? expiresAt,
  }) {
    return AuthUser(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      secret: secret ?? this.secret,
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // AUTH HELPERS

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() {
    return "AuthUser(userId: $userId, username: $username, token: $token, expiresAt: $expiresAt)";
  }
}
