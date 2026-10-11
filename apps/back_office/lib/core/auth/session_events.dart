import 'dart:async';

/// Broadcasts "session lost" events (401 from the backend) so any screen
/// can react without threading a callback through every repository.
class SessionEvents {
  SessionEvents._();

  static final _controller = StreamController<void>.broadcast();

  /// Subscribe to be notified when the stored session is no longer valid.
  static Stream<void> get onUnauthorized => _controller.stream;

  /// Called by ApiClient on 401 — session is already cleared.
  static void fireUnauthorized() {
    if (!_controller.isClosed) _controller.add(null);
  }
  /// Called by the explicit logout button — same effect as a 401:
  /// AuthGate drops the session and shows the login form.
  static void fireLogout() => fireUnauthorized();
}
