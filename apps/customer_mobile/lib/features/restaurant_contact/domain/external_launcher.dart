enum ContactAction { call, whatsapp, telegram, instagram, maps }

enum LaunchResult { opened, unavailable, failed, invalid }

abstract interface class ExternalLauncher {
  Future<LaunchResult> open(ContactAction action, String value);
}
