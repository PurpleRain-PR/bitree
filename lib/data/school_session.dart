import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'browser_session.dart';
import 'school_errors.dart';
import 'school_network.dart';

/// The browser and native HTTP requests share only school-scoped session cookies.
class SchoolSession {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final _cookies = PersistCookieJar(
    storage: const _SecureCookieStorage(),
    persistSession: true,
  );

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';

  Future<List<Cookie>> cookiesFor(Uri source) {
    if (!isSchoolUrl(source)) {
      throw ArgumentError('只接受学校网站的会话');
    }

    return _cookies.loadForRequest(source);
  }

  Future<void> importCookies(Uri source, List<Cookie> cookies) async {
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
    await clearBrowserSession();
    await _cookies.deleteAll();
  }

  Future<void> initializeApp(SchoolNetwork network) async {
    await _request(network.app, document: true);
  }

  Future<Map<String, dynamic>> json(
    SchoolNetwork network,
    String path, {
    Map<String, String>? form,
  }) async {
    final text = await _request(
      network.endpoint(path),
      form: form,
      referer: network.app,
    );
    if (text.trimLeft().startsWith('<')) {
      throw const SchoolRequestError('学校返回了网页，无法读取课表。请重新打开学校网页。');
    }

    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('学校接口返回了无法识别的数据');
    }

    return value;
  }

  Future<String> _request(
    Uri target, {
    Map<String, String>? form,
    Uri? referer,
    bool document = false,
  }) async {
    var uri = target;
    var body = form == null ? null : Uri(queryParameters: form).query;

    for (var redirect = 0; redirect <= 10; redirect++) {
      if (!isSchoolUrl(uri)) {
        throw const SchoolRequestError('学校接口重定向到了未授权的网站');
      }
      if (isSchoolLogin(uri)) throw const SessionExpired();

      final request = await _client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 25));
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.userAgentHeader, userAgent)
        ..set(
          HttpHeaders.acceptHeader,
          document
              ? 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
              : 'application/json, text/javascript, */*; q=0.01',
        )
        ..set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9');
      if (!document) request.headers.set('X-Requested-With', 'XMLHttpRequest');

      if (referer != null) {
        request.headers.set(
          HttpHeaders.refererHeader,
          uri.origin == referer.origin
              ? referer.toString()
              : '${referer.origin}/',
        );
      }
      request.cookies.addAll(await _cookies.loadForRequest(uri));

      if (body != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(body);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      await _cookies.saveFromResponse(uri, response.cookies);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 401) throw const SessionExpired();

      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const SchoolRequestError('学校接口的重定向地址缺失');
        }

        uri = uri.resolve(location);
        if (response.statusCode == 303 ||
            response.statusCode == 301 ||
            response.statusCode == 302) {
          body = null;
        }
        continue;
      }

      if (text.trimLeft().startsWith('<')) {
        final pageError = schoolPageError(text);
        if (pageError != null) throw SchoolRequestError(pageError);
      }
      if (response.statusCode == 403) {
        throw const SchoolRequestError('学校拒绝访问（403），请检查登录方式和账号权限。');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SchoolRequestError('学校服务出错（${response.statusCode}），请稍后重试。');
      }

      return text;
    }

    throw const SchoolRequestError('学校登录反复跳转，请重新登录。');
  }

  void close() => _client.close(force: true);
}

class _SecureCookieStorage implements Storage {
  const _SecureCookieStorage();
  static const _storage = FlutterSecureStorage();

  String _key(String key) => 'cubit.school.cookie.$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key: _key(key));

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: _key(key), value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: _key(key));

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
