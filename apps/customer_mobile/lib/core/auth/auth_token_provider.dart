/// Live access-token holder shared between the AuthBloc (writer) and the
/// HTTP repositories (readers), so `Authorization: Bearer …` headers always
/// reflect the current session without repositories depending on the bloc.
final class AuthTokenProvider {
  String? accessToken;

  /// `Authorization` header value, or null when the guest is anonymous.
  String? get authorizationHeader =>
      accessToken == null ? null : 'Bearer $accessToken';
}
