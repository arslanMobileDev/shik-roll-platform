import 'package:url_launcher/url_launcher.dart';

import '../../data/models/courier_order.dart';

/// External app integrations: phone calls and navigation.
abstract final class Launchers {
  /// Direct call to the client via tel:.
  static Future<bool> callClient(String phone) {
    final uri = Uri(scheme: 'tel', path: phone);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens turn-by-turn navigation to the delivery address.
  ///
  /// Priority: yandexnavi: (coords) -> geo: (address query) -> web Yandex Maps.
  static Future<bool> openNavigator(CourierOrder order) async {
    final address = order.address;

    if (address.lat != null && address.lon != null) {
      final navi = Uri.parse(
        'yandexnavi://build_route_on_map'
        '?lat_to=${address.lat}&lon_to=${address.lon}',
      );
      if (await canLaunchUrl(navi)) {
        return launchUrl(navi, mode: LaunchMode.externalApplication);
      }
    }

    final query = Uri.encodeComponent(address.street);
    final geo = Uri.parse('geo:0,0?q=$query');
    if (await canLaunchUrl(geo)) {
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }

    final web = Uri.parse('https://yandex.ru/maps/?text=$query');
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
