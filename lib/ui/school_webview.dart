import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as browser;

import '../data/school_errors.dart';
import '../data/school_network.dart';
import '../data/school_session.dart';
import 'linux_school_webview.dart';

class SchoolBrowser {
  final _linux = LinuxSchoolBrowser();
  browser.InAppWebViewController? _web;

  Future<void> restoreSession(
    SchoolSession session,
    SchoolNetwork network,
  ) async {
    for (final source in network.sessionUrls) {
      final cookies = await session.cookiesFor(source);
      for (final cookie in cookies) {
        if (io.Platform.isLinux) {
          await _linux.restoreCookie(source, cookie);
        } else {
          final restored = await browser.CookieManager.instance().setCookie(
            url: browser.WebUri(source.toString()),
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path ?? '/',
            expiresDate: cookie.expires?.millisecondsSinceEpoch,
            isSecure: cookie.secure,
            isHttpOnly: cookie.httpOnly,
          );
          if (!restored) {
            throw const SchoolRequestError('无法恢复登录状态，请重试。');
          }
        }
      }
    }
  }

  Future<void> captureSession(
    SchoolSession session,
    SchoolNetwork network,
  ) async {
    for (final source in network.sessionUrls) {
      if (io.Platform.isLinux) {
        await session.importCookies(source, await _linux.cookies(source));
      } else {
        final values = await browser.CookieManager.instance().getCookies(
          url: browser.WebUri(source.toString()),
        );
        final cookies = values.map((value) {
          final cookie = io.Cookie(value.name, value.value.toString())
            ..path = value.path ?? '/'
            ..secure = value.isSecure ?? true
            ..httpOnly = value.isHttpOnly ?? true;
          if (value.domain?.isNotEmpty == true) cookie.domain = value.domain;
          if (value.expiresDate != null) {
            cookie.expires = DateTime.fromMillisecondsSinceEpoch(
              value.expiresDate!,
              isUtc: true,
            );
          }
          return cookie;
        }).toList();
        await session.importCookies(source, cookies);
      }
    }
  }

  Future<Object?> run(String body) async {
    if (io.Platform.isLinux) return _linux.run(body);

    final web = _web;
    if (web == null) throw const SchoolRequestError(schoolPageNotReady);

    final result = await web.callAsyncJavaScript(functionBody: body);
    if (result?.error != null) {
      throw const SchoolRequestError(schoolPageNotReady);
    }

    return result?.value;
  }

  Future<void> load(Uri url) async {
    if (io.Platform.isLinux) {
      await _linux.load(url);
      return;
    }

    final web = _web;
    if (web == null) throw const SchoolRequestError(schoolPageNotReady);

    await web.loadUrl(
      urlRequest: browser.URLRequest(url: browser.WebUri(url.toString())),
    );
  }

  Future<void> navigate(Uri url) async {
    await run(
      'window.location.assign(${jsonEncode(url.toString())}); return null;',
    );
  }
}

class SchoolWebView extends StatelessWidget {
  const SchoolWebView({
    super.key,
    required this.controller,
    required this.initialUrl,
    required this.onLoadStart,
    required this.onLoadStop,
    required this.onProgress,
    required this.onError,
  });

  final SchoolBrowser controller;
  final Uri initialUrl;
  final ValueChanged<Uri> onLoadStart;
  final ValueChanged<Uri> onLoadStop;
  final ValueChanged<double> onProgress;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    if (io.Platform.isLinux) {
      return LinuxSchoolWebView(
        initialUrl: initialUrl,
        onLoadStart: onLoadStart,
        onLoadStop: onLoadStop,
        onProgress: onProgress,
        onError: onError,
      );
    }

    return browser.InAppWebView(
      initialUrlRequest: browser.URLRequest(
        url: browser.WebUri(initialUrl.toString()),
      ),
      initialSettings: browser.InAppWebViewSettings(
        userAgent: SchoolSession.userAgent,
        useShouldOverrideUrlLoading: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        thirdPartyCookiesEnabled: true,
      ),
      onWebViewCreated: (web) => controller._web = web,
      onLoadStart: (_, url) {
        if (url != null) onLoadStart(Uri.parse(url.toString()));
      },
      onLoadStop: (_, url) {
        if (url != null) onLoadStop(Uri.parse(url.toString()));
      },
      shouldOverrideUrlLoading: (_, action) async {
        if (action.isForMainFrame == false) {
          return browser.NavigationActionPolicy.ALLOW;
        }

        final url = action.request.url;
        final allowed = url != null && isSchoolUrl(Uri.parse(url.toString()));
        return allowed
            ? browser.NavigationActionPolicy.ALLOW
            : browser.NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (web, action) async {
        final url = action.request.url;
        if (url != null && isSchoolUrl(Uri.parse(url.toString()))) {
          await web.loadUrl(urlRequest: browser.URLRequest(url: url));
        }
        return false;
      },
      onProgressChanged: (_, value) => onProgress(value / 100),
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true) {
          onError('学校网页加载失败，请检查网络后重试。');
        }
      },
    );
  }
}
