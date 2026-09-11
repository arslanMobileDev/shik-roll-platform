import 'package:url_launcher/url_launcher.dart';
import '../domain/external_launcher.dart';

final class UrlExternalLauncher implements ExternalLauncher {
  UrlExternalLauncher({
    Future<bool> Function(Uri)? canLaunch,
    Future<bool> Function(Uri, LaunchMode)? launch,
  }) : _canLaunch = canLaunch ?? canLaunchUrl,
       _launch = launch ?? ((uri, mode) => launchUrl(uri, mode: mode));
  final Future<bool> Function(Uri) _canLaunch;
  final Future<bool> Function(Uri, LaunchMode) _launch;

  @override
  Future<LaunchResult> open(ContactAction action, String value) async {
    final uri = _uri(action, value);
    if (uri == null) return LaunchResult.invalid;
    try {
      final supported = await _canLaunch(uri);
      if (uri.scheme == 'tel') {
        if (!supported) return LaunchResult.unavailable;
        return await _launch(uri, LaunchMode.externalApplication)
            ? LaunchResult.opened
            : LaunchResult.failed;
      }
      // Prefer the installed app, then use the web page in a browser.
      if (supported) {
        try {
          if (await _launch(uri, LaunchMode.externalNonBrowserApplication)) {
            return LaunchResult.opened;
          }
        } on Exception {
          /* Continue with the HTTPS fallback. */
        }
      }
      return await _launch(uri, LaunchMode.externalApplication)
          ? LaunchResult.opened
          : LaunchResult.unavailable;
    } on Exception {
      return LaunchResult.failed;
    }
  }

  Uri? _uri(ContactAction action, String raw) {
    final value = raw.trim();
    switch (action) {
      case ContactAction.call:
      case ContactAction.whatsapp:
        if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value)) return null;
        return action == ContactAction.call
            ? Uri(scheme: 'tel', path: value)
            : Uri.https('wa.me', '/${value.substring(1)}');
      case ContactAction.telegram:
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(value)) {
          return null;
        }
        return Uri.https('t.me', '/$value');
      case ContactAction.maps:
        if (value.isEmpty || value.length > 1000) return null;
        return Uri.https('yandex.ru', '/maps/', {'text': value});
    }
  }
}
