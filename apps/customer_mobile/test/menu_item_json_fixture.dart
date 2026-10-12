/// Raw `MenuItemEntity` JSON as the guest API returns it (openapi.json), so
/// the model and the rendering tests share one realistic payload.
///
/// `imageUrl` is omitted unless passed, keeping "field absent" and "field
/// explicitly null" distinguishable.
const Object _absent = Object();

Map<String, dynamic> menuItemJson({
  Object? imageUrl = _absent,
  String name = 'Филадельфия',
  List<Map<String, dynamic>> modifierGroups = const [],
}) {
  final json = <String, dynamic>{
    'id': 'item-1',
    'sku': 'R-001',
    'name': name,
    'description': 'Лосось, сыр, огурец.',
    'category': {'id': 'cat-rolls', 'name': 'Роллы'},
    'weight': 250,
    'calories': 320,
    'price': {'effective': 390.0},
    'sortOrder': 0,
    'isPopular': true,
    'isNew': false,
    'isHalal': true,
    'available': true,
    'modifierGroups': modifierGroups,
  };
  if (imageUrl != _absent) json['imageUrl'] = imageUrl;
  return json;
}
