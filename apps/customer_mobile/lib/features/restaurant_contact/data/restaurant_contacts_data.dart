import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_token_provider.dart';
import '../../../core/network/api_client.dart';
import '../domain/restaurant_contacts.dart';

abstract final class ContactsDto {
  static String? text(Object? value) {
    if (value == null) return null;
    if (value is! String || value.length > 1000) {
      throw const FormatException('Invalid contact field');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? phone(Object? value) {
    final input = text(value);
    if (input == null) return null;
    final normalized = input.replaceAll(RegExp(r'[\s()\-]'), '');
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalized)
        ? normalized
        : null;
  }

  static RestaurantContacts parse(Map<String, dynamic> json) {
    final branch = text(json['branchId']);
    if (branch == null) throw const FormatException('Missing branch');
    final username = text(json['telegram'])?.replaceFirst(RegExp(r'^@'), '');
    final contacts = RestaurantContacts(
      branchId: branch,
      phone: phone(json['phone']),
      whatsapp: phone(json['whatsapp']),
      telegram:
          username != null &&
              RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(username)
          ? username
          : null,
      workingHours: text(json['workingHours']),
      address: text(json['address']),
    );
    if (contacts.isEmpty) throw const FormatException('Empty contacts');
    return contacts;
  }

  static Map<String, dynamic> encode(RestaurantContacts contacts) => {
    'branchId': contacts.branchId,
    'phone': contacts.phone,
    'whatsapp': contacts.whatsapp,
    'telegram': contacts.telegram,
    'workingHours': contacts.workingHours,
    'address': contacts.address,
  };
}

abstract interface class ContactsDataSource {
  Future<String> resolveBranch(ContactTarget target);
  Future<RestaurantContacts> fetch(String branchId);
}

final class RemoteContactsDataSource implements ContactsDataSource {
  RemoteContactsDataSource(this.client, this.tokens);
  final ApiClient client;
  final AuthTokenProvider tokens;
  @override
  Future<String> resolveBranch(ContactTarget target) async {
    if (target.orderId == null) return target.branchId!;
    final auth = tokens.authorizationHeader;
    if (auth == null) throw const ContactsAccessDenied();
    final response = await client.dio.get<Map<String, dynamic>>(
      '/orders/${Uri.encodeComponent(target.orderId!)}',
      options: Options(headers: {'Authorization': auth}),
    );
    final branch = ContactsDto.text(response.data?['branchId']);
    if (branch == null) throw const FormatException('Order branch missing');
    return branch;
  }

  @override
  Future<RestaurantContacts> fetch(String branchId) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/restaurants/contacts',
      queryParameters: {'branchId': branchId},
    );
    final contacts = ContactsDto.parse(response.data ?? {});
    if (contacts.branchId != branchId) {
      throw const FormatException('Branch mismatch');
    }
    return contacts;
  }
}

final class ContactsAccessDenied implements Exception {
  const ContactsAccessDenied();
}

abstract interface class ContactsCache {
  Future<RestaurantContacts?> read(String key);
  Future<void> write(String key, RestaurantContacts contacts);
}

final class PreferencesContactsCache implements ContactsCache {
  PreferencesContactsCache(this.preferences, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final SharedPreferences preferences;
  final DateTime Function() now;
  static const ttl = Duration(days: 7);
  @override
  Future<RestaurantContacts?> read(String key) async {
    try {
      final value = preferences.getString('restaurant_contacts.v1.$key');
      if (value == null) return null;
      final json = jsonDecode(value) as Map<String, dynamic>;
      final age = now().toUtc().difference(
        DateTime.parse(json['savedAt'] as String),
      );
      if (age.isNegative || age > ttl) return null;
      return ContactsDto.parse(json['contacts'] as Map<String, dynamic>);
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(String key, RestaurantContacts contacts) async {
    await preferences.setString(
      'restaurant_contacts.v1.$key',
      jsonEncode({
        'savedAt': now().toUtc().toIso8601String(),
        'contacts': ContactsDto.encode(contacts),
      }),
    );
  }
}

final class CachedRestaurantContactsRepository
    implements RestaurantContactsRepository {
  CachedRestaurantContactsRepository(this.remote, this.cache, {this.defaults});
  final ContactsDataSource remote;
  final ContactsCache cache;
  final RestaurantContacts? defaults;
  @override
  Future<ContactResult> getContacts(ContactTarget target) async {
    String? branchId = target.branchId;
    try {
      branchId = await remote.resolveBranch(target);
    } on ContactsAccessDenied {
      throw const ContactsUnavailable();
    } on DioException catch (error) {
      if ([401, 403, 404].contains(error.response?.statusCode)) {
        throw const ContactsUnavailable();
      }
      return _fallback(target, branchId);
    } on Exception {
      return _fallback(target, branchId);
    }
    try {
      final contacts = await remote.fetch(branchId);
      if (contacts.branchId != branchId || contacts.isEmpty) {
        throw const FormatException('Invalid contacts');
      }
      try {
        await cache.write(target.cacheKey, contacts);
      } on Exception {
        /* Cache is best effort. */
      }
      return ContactResult(contacts, ContactSource.server);
    } on Exception {
      return _fallback(target, branchId);
    }
  }

  Future<ContactResult> _fallback(
    ContactTarget target,
    String? branchId,
  ) async {
    RestaurantContacts? saved;
    try {
      saved = await cache.read(target.cacheKey);
    } on Exception {
      saved = null;
    }
    if (saved != null &&
        !saved.isEmpty &&
        (branchId == null || saved.branchId == branchId)) {
      return ContactResult(saved, ContactSource.cache);
    }
    if (defaults != null &&
        defaults!.branchId == branchId &&
        !defaults!.isEmpty) {
      return ContactResult(defaults!, ContactSource.defaults);
    }
    throw const ContactsUnavailable();
  }
}
