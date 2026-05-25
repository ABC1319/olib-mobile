/// `/auth/register` 返回 — anon 握手 token，**没有** user_id / role。
/// 后端语义：register 仅签发匿名 device JWT（audience=anon），
/// 真正的用户身份要等用户扫码授权后由 `/auth/status` 返回正式 token 才有。
class AnonTokenResponse {
  final String token;
  final int expiresIn; // 秒

  const AnonTokenResponse({
    required this.token,
    required this.expiresIn,
  });

  factory AnonTokenResponse.fromJson(Map<String, dynamic> json) {
    return AnonTokenResponse(
      token: json['token'] as String,
      expiresIn: json['expires_in'] as int? ?? 30 * 60,
    );
  }
}

class QrCodeResponse {
  final String qrUrl;
  final int expireSeconds;

  const QrCodeResponse({
    required this.qrUrl,
    required this.expireSeconds,
  });

  factory QrCodeResponse.fromJson(Map<String, dynamic> json) {
    return QrCodeResponse(
      qrUrl: json['qr_url'] as String? ?? '',
      expireSeconds: json['expire_seconds'] as int? ?? 300,
    );
  }
}

class AuthStatusResponse {
  final String? status;
  final String? token;
  final int? userId;

  const AuthStatusResponse({
    this.status,
    this.token,
    this.userId,
  });

  factory AuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return AuthStatusResponse(
      status: json['status'] as String?,
      token: json['token'] as String?,
      userId: json['user_id'] as int?,
    );
  }
}
