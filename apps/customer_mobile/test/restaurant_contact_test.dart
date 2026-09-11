import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer_mobile/features/restaurant_contact/domain/restaurant_contacts.dart';
import 'package:customer_mobile/features/restaurant_contact/domain/external_launcher.dart';
import 'package:customer_mobile/features/restaurant_contact/data/restaurant_contacts_data.dart';
import 'package:customer_mobile/features/restaurant_contact/data/url_external_launcher.dart';
import 'package:customer_mobile/features/restaurant_contact/presentation/restaurant_contact_cubit.dart';
import 'package:customer_mobile/features/restaurant_contact/presentation/restaurant_contact_sheet.dart';
import 'package:customer_mobile/core/theme/app_theme.dart';

class RepositoryMock extends Mock implements RestaurantContactsRepository {}

class RemoteMock extends Mock implements ContactsDataSource {}

class CacheMock extends Mock implements ContactsCache {}

class LauncherMock extends Mock implements ExternalLauncher {}

const target = ContactTarget.branch('branch-a');
const contacts = RestaurantContacts(
  branchId: 'branch-a',
  phone: '+79991234567',
  telegram: 'restaurant_test',
  address: 'Тестовый адрес',
  workingHours: '10:00–22:00 МСК',
);
const result = ContactResult(contacts, ContactSource.server);

void main() {
  late RepositoryMock repository;
  setUp(() {
    repository = RepositoryMock();
  });
  test('use case forwards the exact branch', () async {
    when(() => repository.getContacts(target)).thenAnswer((_) async => result);
    expect(await GetRestaurantContactsUseCase(repository)(target), result);
    verify(() => repository.getContacts(target)).called(1);
  });
  test('use case rejects missing branch without a request', () async {
    await expectLater(
      GetRestaurantContactsUseCase(repository)(const ContactTarget.branch('')),
      throwsA(isA<ContactsUnavailable>()),
    );
    verifyZeroInteractions(repository);
  });
  blocTest<RestaurantContactCubit, RestaurantContactState>(
    'loads contacts',
    build: () {
      when(
        () => repository.getContacts(target),
      ).thenAnswer((_) async => result);
      return RestaurantContactCubit(GetRestaurantContactsUseCase(repository));
    },
    act: (cubit) => cubit.load(target),
    expect: () => [const ContactLoading(), const ContactLoaded(result)],
  );
  blocTest<RestaurantContactCubit, RestaurantContactState>(
    'surfaces failure',
    build: () {
      when(
        () => repository.getContacts(target),
      ).thenThrow(const ContactsUnavailable());
      return RestaurantContactCubit(GetRestaurantContactsUseCase(repository));
    },
    act: (cubit) => cubit.load(target),
    expect: () => [const ContactLoading(), const ContactError()],
  );
  test('closed cubit ignores pending response', () async {
    final pending = Completer<ContactResult>();
    when(
      () => repository.getContacts(target),
    ).thenAnswer((_) => pending.future);
    final cubit = RestaurantContactCubit(
      GetRestaurantContactsUseCase(repository),
    );
    final work = cubit.load(target);
    await cubit.close();
    pending.complete(result);
    await work;
    expect(cubit.state, const ContactLoading());
  });
  test('latest request wins', () async {
    final first = Completer<ContactResult>();
    const other = ContactTarget.branch('branch-b');
    const second = ContactResult(
      RestaurantContacts(branchId: 'branch-b', address: 'B'),
      ContactSource.server,
    );
    when(() => repository.getContacts(target)).thenAnswer((_) => first.future);
    when(() => repository.getContacts(other)).thenAnswer((_) async => second);
    final cubit = RestaurantContactCubit(
      GetRestaurantContactsUseCase(repository),
    );
    final work = cubit.load(target);
    await cubit.load(other);
    first.complete(result);
    await work;
    expect(cubit.state, const ContactLoaded(second));
    await cubit.close();
  });
  group('repository fallback', () {
    late RemoteMock remote;
    late CacheMock cache;
    late CachedRestaurantContactsRepository sut;
    setUp(() {
      remote = RemoteMock();
      cache = CacheMock();
      sut = CachedRestaurantContactsRepository(
        remote,
        cache,
        defaults: contacts,
      );
      when(
        () => remote.resolveBranch(target),
      ).thenAnswer((_) async => 'branch-a');
      when(
        () => remote.fetch('branch-a'),
      ).thenThrow(const ContactsUnavailable());
      when(() => cache.read(target.cacheKey)).thenAnswer((_) async => null);
    });
    test('uses matching configured defaults', () async {
      expect((await sut.getContacts(target)).source, ContactSource.defaults);
    });
    test('prefers cached contacts to defaults', () async {
      when(() => cache.read(target.cacheKey)).thenAnswer((_) async => contacts);
      expect((await sut.getContacts(target)).source, ContactSource.cache);
    });
    test('fresh result survives cache write failure', () async {
      when(() => remote.fetch('branch-a')).thenAnswer((_) async => contacts);
      when(
        () => cache.write(target.cacheKey, contacts),
      ).thenThrow(Exception('disk'));
      expect(await sut.getContacts(target), result);
    });
    test('wrong branch cache is discarded', () async {
      when(() => cache.read(target.cacheKey)).thenAnswer(
        (_) async =>
            const RestaurantContacts(branchId: 'other', phone: '+79999999999'),
      );
      expect((await sut.getContacts(target)).source, ContactSource.defaults);
    });
    test('unknown order never uses current branch defaults', () async {
      const order = ContactTarget.order('order-1');
      when(
        () => remote.resolveBranch(order),
      ).thenThrow(const ContactsUnavailable());
      when(() => cache.read(order.cacheKey)).thenAnswer((_) async => null);
      await expectLater(
        sut.getContacts(order),
        throwsA(isA<ContactsUnavailable>()),
      );
    });
    test('denied order never uses cached contacts', () async {
      const order = ContactTarget.order('order-1');
      when(
        () => remote.resolveBranch(order),
      ).thenThrow(const ContactsAccessDenied());
      await expectLater(
        sut.getContacts(order),
        throwsA(isA<ContactsUnavailable>()),
      );
      verifyZeroInteractions(cache);
    });
  });
  test('persistent cache expires after seven days', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime.utc(2026, 9, 12);
    final cache = PreferencesContactsCache(prefs, now: () => now);
    await cache.write('a', contacts);
    expect(await cache.read('a'), contacts);
    now = now.add(const Duration(days: 8));
    expect(await cache.read('a'), isNull);
  });
  test('DTO rejects executable URLs and normalizes phone', () {
    final parsed = ContactsDto.parse({
      'branchId': 'branch-a',
      'phone': '+7 (999) 123-45-67',
      'telegram': 'https://evil.example',
      'whatsapp': 'javascript:alert(1)',
    });
    expect(parsed.phone, '+79991234567');
    expect(parsed.telegram, isNull);
    expect(parsed.whatsapp, isNull);
  });
  test('DTO rejects empty and malformed payload', () {
    expect(() => ContactsDto.parse({'branchId': 'a'}), throwsFormatException);
    expect(
      () => ContactsDto.parse({'branchId': 'a', 'phone': 123}),
      throwsFormatException,
    );
  });
  test('unsupported tel never launches', () async {
    var launched = false;
    final launcher = UrlExternalLauncher(
      canLaunch: (_) async => false,
      launch: (_, _) async {
        launched = true;
        return true;
      },
    );
    expect(
      await launcher.open(ContactAction.call, '+79991234567'),
      LaunchResult.unavailable,
    );
    expect(launched, isFalse);
  });
  test('messenger falls back to HTTPS browser', () async {
    final modes = <LaunchMode>[];
    final launcher = UrlExternalLauncher(
      canLaunch: (_) async => true,
      launch: (uri, mode) async {
        expect(uri.toString(), 'https://wa.me/79991234567');
        modes.add(mode);
        return mode == LaunchMode.externalApplication;
      },
    );
    expect(
      await launcher.open(ContactAction.whatsapp, '+79991234567'),
      LaunchResult.opened,
    );
    expect(modes, [
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
    ]);
  });
  test('launcher contains platform exceptions', () async {
    final launcher = UrlExternalLauncher(
      canLaunch: (_) async => true,
      launch: (_, _) async => throw Exception('plugin'),
    );
    expect(
      await launcher.open(ContactAction.call, '+79991234567'),
      LaunchResult.failed,
    );
    expect(
      await launcher.open(ContactAction.telegram, 'https://evil.example'),
      LaunchResult.invalid,
    );
  });
  testWidgets('sheet shows fallback contacts and launcher error', (
    tester,
  ) async {
    final launcher = LauncherMock();
    when(
      () => launcher.open(ContactAction.call, contacts.phone!),
    ).thenAnswer((_) async => LaunchResult.unavailable);
    when(() => repository.getContacts(target)).thenAnswer(
      (_) async => const ContactResult(contacts, ContactSource.defaults),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRestaurantContactSheet(
                context,
                target: target,
                getContacts: GetRestaurantContactsUseCase(repository),
                launcher: launcher,
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('10:00–22:00 МСК'), findsOneWidget);
    expect(find.textContaining('резервные контакты'), findsOneWidget);
    await tester.tap(find.text('Позвонить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Звонки недоступны'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sheet retry recovers from error', (tester) async {
    when(
      () => repository.getContacts(target),
    ).thenThrow(const ContactsUnavailable());
    final cubit = RestaurantContactCubit(
      GetRestaurantContactsUseCase(repository),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => BlocProvider.value(
              value: cubit,
              child: RestaurantContactSheet(
                target: target,
                launcher: LauncherMock(),
                messenger: ScaffoldMessenger.of(context),
              ),
            ),
          ),
        ),
      ),
    );
    await cubit.load(target);
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    when(() => repository.getContacts(target)).thenAnswer((_) async => result);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Позвонить'), findsOneWidget);
    await cubit.close();
  });
}
