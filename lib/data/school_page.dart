import 'dart:convert';

import 'school_errors.dart';
import 'school_network.dart';

class SchoolPage {
  SchoolPage({required this._network, required this._evaluate});

  final SchoolNetwork _network;
  final Future<Object?> Function(String) _evaluate;

  Future<void> checkLogin() async {
    final page = await _loadedPage(schoolLoginNotReady);
    if (!_network.isLoginLanding(page.url)) {
      throw const SchoolRequestError(schoolLoginNotReady);
    }
  }

  Future<void> checkSchedule() async {
    final page = await _loadedPage(schoolScheduleNotReady);
    if (!_network.isApp(page.url) || !page.text.contains('我的课表')) {
      throw const SchoolRequestError(schoolScheduleNotReady);
    }
  }

  Future<({Uri url, String text})> _loadedPage(String notReady) async {
    final result = await _evaluate("""
      return {
        url: window.location.href,
        ready: document.readyState === 'complete',
        loginForm: document.querySelector('input[type="password"]') !== null,
        text: document.title + String.fromCharCode(10) +
          (document.body ? document.body.innerText : '')
      };
    """);

    if (result is! Map) throw const SchoolRequestError(schoolPageNotReady);

    final text = result['text'] as String;
    final error = schoolPageError(text);
    if (error != null) throw SchoolRequestError(error);

    final url = Uri.tryParse(result['url'] as String);
    if (url != null && (isSchoolLogin(url) || result['loginForm'] == true)) {
      throw const SessionExpired();
    }
    if (result['ready'] != true || url == null) {
      throw SchoolRequestError(notReady);
    }

    return (url: url, text: text);
  }

  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, String>? form,
  }) async {
    final result = await _evaluate("""
      if (location.origin !== ${jsonEncode(_network.app.origin)} ||
          decodeURIComponent(location.pathname) !== ${jsonEncode(_network.app.path)}) {
        return {kind: 'notReady'};
      }
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 25000);
      try {
        const form = ${jsonEncode(form)};
        const options = {
          method: form === null ? 'GET' : 'POST',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
          },
          signal: controller.signal,
        };
        if (form !== null) {
          options.headers['Content-Type'] = 'application/x-www-form-urlencoded;charset=UTF-8';
          options.body = new URLSearchParams(form).toString();
        }
        const response = await fetch(${jsonEncode(_network.endpoint(path).toString())}, options);
        if (response.status === 401) return {kind: 'login'};
        if (response.status === 403) return {kind: 'notReady'};
        if (!response.ok) return {kind: 'http', status: response.status};
        const text = await response.text();
        try {
          return {kind: 'data', data: JSON.parse(text)};
        } catch (_) {
          return {kind: 'page', url: response.url, text};
        }
      } catch (_) {
        return {kind: 'network'};
      } finally {
        clearTimeout(timeout);
      }
    """);
    if (result is! Map) throw const SchoolRequestError(schoolScheduleNotReady);
    switch (result['kind']) {
      case 'data':
        final data = result['data'];
        if (data is! Map) {
          throw const SchoolRequestError(schoolScheduleNotReady);
        }
        return Map<String, dynamic>.from(data);
      case 'login':
        throw const SessionExpired();
      case 'page':
        final url = Uri.tryParse(result['url']?.toString() ?? '');
        if (url != null && isSchoolLogin(url)) {
          throw const SessionExpired();
        }
        final error = schoolPageError(result['text']?.toString() ?? '');
        throw SchoolRequestError(error ?? schoolScheduleNotReady);
      case 'http':
        throw SchoolRequestError('学校服务出错（${result['status']}），请稍后重试。');
      case 'network':
        throw const SchoolRequestError('读取学校数据失败，请检查网络后重试。');
      default:
        throw const SchoolRequestError(schoolScheduleNotReady);
    }
  }
}
