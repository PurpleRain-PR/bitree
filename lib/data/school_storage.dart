import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'school_network.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);

const _credentialsKey = 'bitree.school.credentials';
// Keep the existing keys so an upgrade preserves saved sessions.
const _cookiePrefix = 'cubit.school.cookie.';

class SchoolCredentials {
  const SchoolCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

class SchoolStorage {
  PersistCookieJar _cookies = _createCookieJar();

  static PersistCookieJar _createCookieJar() => PersistCookieJar(
    storage: const _SecureCookieStorage(),
    persistSession: true,
  );

  Future<SchoolCredentials?> readCredentials() async {
    final saved = await _accessStorage(
      () => _secureStorage.read(key: _credentialsKey),
    );
    if (saved == null) return null;

    Object? value;
    try {
      value = jsonDecode(saved);
    } on FormatException {
      throw const SchoolStorageError('保存的登录信息已损坏，请退出账号后重新登录。');
    }

    return switch (value) {
      {'username': final String username, 'password': final String password} =>
        SchoolCredentials(username: username, password: password),
      _ => throw const SchoolStorageError('保存的登录信息已损坏，请退出账号后重新登录。'),
    };
  }

  Future<void> saveCredentials(SchoolCredentials credentials) => _accessStorage(
    () => _secureStorage.write(
      key: _credentialsKey,
      value: jsonEncode({
        'username': credentials.username,
        'password': credentials.password,
      }),
    ),
  );

  Future<List<Cookie>> cookiesFor(Uri source) {
    if (!isSchoolUrl(source)) {
      throw ArgumentError('只接受学校网站的会话');
    }

    return _cookies.loadForRequest(source);
  }

  Future<void> saveCookies(Uri source, List<Cookie> cookies) async {
    if (!isSchoolUrl(source)) {
      throw ArgumentError('只接受学校网站的会话');
    }

    for (final cookie in cookies) {
      final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
      if (domain != null &&
          domain.isNotEmpty &&
          (!isSchoolUrl(Uri.https(domain)) ||
              (source.host != domain && !source.host.endsWith('.$domain')))) {
        throw const FormatException('学校会话的 Cookie 域名不匹配');
      }
    }

    await _cookies.saveFromResponse(source, cookies);
  }

  Future<void> clear() async {
    await _accessStorage(() async {
      final saved = await _secureStorage.readAll();
      for (final key in saved.keys) {
        if (key == _credentialsKey || key.startsWith(_cookiePrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
    });

    _cookies = _createCookieJar();
  }
}

class SchoolStorageError implements Exception {
  const SchoolStorageError(this.message, [this.cause]);

  final String message;
  final Exception? cause;

  @override
  String toString() => message;
}

Future<T> _accessStorage<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on Exception catch (error) {
    throw SchoolStorageError(
      Platform.isLinux ? '无法访问系统密钥环，请确认密钥环已解锁后重试。' : '无法访问系统安全存储，请稍后重试。',
      error,
    );
  }
}

class _SecureCookieStorage implements Storage {
  const _SecureCookieStorage();

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) =>
      _accessStorage(() => _secureStorage.read(key: '$_cookiePrefix$key'));

  @override
  Future<void> write(String key, String value) => _accessStorage(
    () => _secureStorage.write(key: '$_cookiePrefix$key', value: value),
  );

  @override
  Future<void> delete(String key) =>
      _accessStorage(() => _secureStorage.delete(key: '$_cookiePrefix$key'));

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
