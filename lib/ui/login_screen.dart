import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as browser;

import '../data/school_session.dart';
import '../schedule/controller.dart';
import 'linux_school_webview.dart';

enum SchoolAction { signIn, importSchedule }

Future<bool?> openSchoolPage(
  BuildContext context,
  ScheduleController controller, {
  required SchoolAction action,
}) async {
  if (controller.busy) return null;
  final network = await showModalBottomSheet<SchoolNetwork>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Text(
                action == SchoolAction.importSchedule ? '导入课表' : '登录账号',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('校园网'),
              subtitle: const Text('需连接校园网'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, SchoolNetwork.campus),
            ),
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('WebVPN'),
              subtitle: const Text('校外访问'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, SchoolNetwork.webvpn),
            ),
          ],
        ),
      ),
    ),
  );
  if (network == null || !context.mounted || controller.busy) return null;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          LoginScreen(controller: controller, network: network, action: action),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    required this.network,
    required this.action,
  });
  final ScheduleController controller;
  final SchoolNetwork network;
  final SchoolAction action;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SchoolNetwork get _network => widget.network;
  bool get _importing => widget.action == SchoolAction.importSchedule;
  late SchoolAction _step;
  late final Uri _initialUrl;
  bool _browserReady = false;
  browser.InAppWebViewController? _web;
  LinuxSchoolBrowser? _linux;
  bool _busy = false;
  bool _gatewayOpened = false;
  bool _courseOpened = false;
  double _progress = 0;
  String? _error;
  static const _pageNotReady = '学校网页还在加载，请稍后重试。';
  static const _notReady = '还未识别到课表，请等页面加载完成后重试。';
  static const _loginNotReady = '请先在学校网页中完成登录。';

  @override
  void initState() {
    super.initState();
    final signedIn =
        widget.controller.accountStatus == AccountStatus.signedIn &&
        widget.controller.network == _network;
    _step = _importing && signedIn
        ? SchoolAction.importSchedule
        : SchoolAction.signIn;
    _initialUrl = _step == SchoolAction.signIn
        ? _network.loginEntry
        : _network.app;
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = widget.controller.school.session;
      for (final source in _network.sessionUrls) {
        final cookies = await session.cookiesFor(source);
        for (final cookie in cookies) {
          if (io.Platform.isLinux) {
            await LinuxSchoolBrowser().restoreCookie(source, cookie);
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
      if (mounted) setState(() => _browserReady = true);
    } catch (error) {
      if (mounted) setState(() => _error = operationError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Object?> _run(String body) async {
    if (io.Platform.isLinux) {
      if (_linux == null) throw const SchoolRequestError(_pageNotReady);
      return _linux!.run(body);
    }
    if (_web == null) throw const SchoolRequestError(_pageNotReady);
    final result = await _web!.callAsyncJavaScript(functionBody: body);
    if (result?.error != null) throw const SchoolRequestError(_pageNotReady);
    return result?.value;
  }

  Future<void> _navigateInPage(Uri url) async {
    await _run(
      'window.location.assign(${jsonEncode(url.toString())}); return null;',
    );
  }

  void _loadStarted(Uri url) {
    if (!mounted) return;
    setState(() {
      _progress = 0;
      _error = null;
      if (isSchoolLogin(url)) _step = SchoolAction.signIn;
    });
    if (isSchoolLogin(url)) widget.controller.requireLogin();
  }

  Future<void> _pageLoaded(Uri url) async {
    if (!mounted) return;
    try {
      if (_step == SchoolAction.signIn) {
        if (_network.isLoginLanding(url)) await _finish();
        return;
      }
      if (_network.isGatewayHome(url) && !_gatewayOpened) {
        _gatewayOpened = true;
        await _navigateInPage(SchoolNetwork.webvpnTeachingLogin);
      } else if (_network.isAuthLanding(url) && !_courseOpened) {
        _courseOpened = true;
        await _navigateInPage(_network.app);
      }
      // Course data is read only when the user presses the import button.
    } catch (error) {
      if (mounted) setState(() => _error = operationError(error));
    }
  }

  Future<void> _load(Uri url) async {
    if (io.Platform.isLinux) {
      await _linux?.load(url);
    } else {
      await _web?.loadUrl(
        urlRequest: browser.URLRequest(url: browser.WebUri(url.toString())),
      );
    }
  }

  Future<void> _restart() async {
    setState(() {
      _gatewayOpened = false;
      _courseOpened = false;
      _error = null;
    });
    if (!_browserReady) {
      await _restoreSession();
      return;
    }
    try {
      await _load(
        _step == SchoolAction.signIn ? _network.loginEntry : _network.app,
      );
    } catch (error) {
      if (mounted) setState(() => _error = operationError(error));
    }
  }

  Future<void> _checkReady({required bool forSchedule}) async {
    final result = await _run("""
      return {
        url: window.location.href,
        ready: document.readyState === 'complete',
        loginForm: document.querySelector('input[type="password"]') !== null,
        text: document.title + String.fromCharCode(10) +
          (document.body ? document.body.innerText : '')
      };
    """);
    if (result is! Map) throw const SchoolRequestError(_pageNotReady);
    final error = schoolPageError(result['text']?.toString() ?? '');
    if (error != null) throw SchoolRequestError(error);
    final url = Uri.tryParse(result['url']?.toString() ?? '');
    if (url != null && (isSchoolLogin(url) || result['loginForm'] == true)) {
      throw const SessionExpired();
    }
    if (result['ready'] != true ||
        url == null ||
        (forSchedule
            ? !_network.isApp(url) ||
                  !(result['text'] as String).contains('我的课表')
            : !_network.isLoginLanding(url))) {
      throw SchoolRequestError(forSchedule ? _notReady : _loginNotReady);
    }
  }

  Future<Map<String, dynamic>> _fetchJson(
    String path, {
    Map<String, String>? form,
  }) async {
    final result = await _run("""
      if (location.origin !== ${jsonEncode(_network.app.origin)} ||
          decodeURIComponent(location.pathname) !== ${jsonEncode(_network.app.path)}) {
        return {kind: 'notReady'};
      }
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 25000);
      try {
        const response = await fetch(${jsonEncode(_network.endpoint(path).toString())}, {
          method: ${jsonEncode(form == null ? 'GET' : 'POST')},
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
            ${form == null ? '' : "'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',"}
          },
          ${form == null ? '' : 'body: new URLSearchParams(${jsonEncode(form)}).toString(),'}
          signal: controller.signal
        });
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
    if (result is! Map) throw const SchoolRequestError(_notReady);
    switch (result['kind']) {
      case 'data':
        final data = result['data'];
        if (data is! Map) throw const SchoolRequestError(_notReady);
        return Map<String, dynamic>.from(data);
      case 'login':
        throw const SessionExpired();
      case 'page':
        final url = Uri.tryParse(result['url']?.toString() ?? '');
        if (url != null && isSchoolLogin(url)) {
          throw const SessionExpired();
        }
        final error = schoolPageError(result['text']?.toString() ?? '');
        throw SchoolRequestError(error ?? _notReady);
      case 'http':
        throw SchoolRequestError('学校服务出错（${result['status']}），请稍后重试。');
      case 'network':
        throw const SchoolRequestError('读取学校数据失败，请检查网络后重试。');
      default:
        throw const SchoolRequestError(_notReady);
    }
  }

  Future<void> _captureCookies() async {
    final session = widget.controller.school.session;
    for (final source in _network.sessionUrls) {
      if (io.Platform.isLinux) {
        await session.importCookies(source, await _linux!.cookies(source));
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

  Future<void> _finish() async {
    if (_busy || !_browserReady) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signingIn = _step == SchoolAction.signIn;
      await _checkReady(forSchedule: !signingIn);
      await _captureCookies();
      final success = signingIn
          ? await widget.controller.completeSignIn(_network)
          : await widget.controller.synchronize(
              using: _network,
              request: _fetchJson,
            );
      if (!mounted) return;
      if (success) {
        if (signingIn && _importing) {
          setState(() {
            _step = SchoolAction.importSchedule;
            _gatewayOpened = false;
            _courseOpened = false;
          });
          await _navigateInPage(
            _network == SchoolNetwork.webvpn
                ? SchoolNetwork.webvpnTeachingLogin
                : _network.app,
          );
        } else {
          Navigator.of(context).pop(true);
        }
      } else if (!signingIn && widget.controller.needsLogin) {
        await _loginAgain();
      } else {
        setState(() => _error = widget.controller.error);
      }
    } on SessionExpired {
      widget.controller.requireLogin();
      if (mounted) {
        if (_step == SchoolAction.importSchedule) {
          await _loginAgain();
        } else {
          setState(() => _error = _loginNotReady);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginAgain() async {
    setState(() {
      _step = SchoolAction.signIn;
      _gatewayOpened = false;
      _courseOpened = false;
      _error = '登录已过期，请重新登录。';
    });
    try {
      await _load(_network.loginEntry);
    } catch (error) {
      if (mounted) setState(() => _error = operationError(error));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_step == SchoolAction.signIn ? '登录账号' : '导入课表'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                '登录状态保存在本机。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              height: 4,
              child: _progress > 0 && _progress < 1
                  ? LinearProgressIndicator(value: _progress)
                  : null,
            ),
            Expanded(
              child: !_browserReady
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _restoreSession,
                              child: const Text('重试'),
                            ),
                    )
                  : io.Platform.isLinux
                  ? LinuxSchoolWebView(
                      initialUrl: _initialUrl,
                      onCreated: (controller) => _linux = controller,
                      onLoadStart: _loadStarted,
                      onLoadStop: _pageLoaded,
                      onProgress: (value) {
                        if (mounted) setState(() => _progress = value);
                      },
                      onError: (value) {
                        if (mounted) setState(() => _error = value);
                      },
                    )
                  : browser.InAppWebView(
                      initialUrlRequest: browser.URLRequest(
                        url: browser.WebUri(_initialUrl.toString()),
                      ),
                      initialSettings: browser.InAppWebViewSettings(
                        userAgent: SchoolSession.userAgent,
                        useShouldOverrideUrlLoading: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        supportMultipleWindows: true,
                        thirdPartyCookiesEnabled: true,
                      ),
                      onWebViewCreated: (controller) => _web = controller,
                      onLoadStart: (_, url) {
                        if (url != null) {
                          _loadStarted(Uri.parse(url.toString()));
                        }
                      },
                      onLoadStop: (_, url) {
                        if (url != null) _pageLoaded(Uri.parse(url.toString()));
                      },
                      shouldOverrideUrlLoading: (_, action) async =>
                          action.isForMainFrame == false ||
                              (action.request.url != null &&
                                  isSchoolUrl(
                                    Uri.parse(action.request.url.toString()),
                                  ))
                          ? browser.NavigationActionPolicy.ALLOW
                          : browser.NavigationActionPolicy.CANCEL,
                      onCreateWindow: (controller, action) async {
                        final url = action.request.url;
                        if (url != null &&
                            isSchoolUrl(Uri.parse(url.toString()))) {
                          await controller.loadUrl(
                            urlRequest: browser.URLRequest(url: url),
                          );
                        }
                        return false;
                      },
                      onProgressChanged: (_, value) {
                        if (mounted) setState(() => _progress = value / 100);
                      },
                      onReceivedError: (_, request, error) {
                        if (request.isForMainFrame == true && mounted) {
                          setState(() => _error = '学校网页加载失败，请检查网络后重试。');
                        }
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '重新打开网页',
                    onPressed: _busy ? null : _restart,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || !_browserReady ? null : _finish,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _step == SchoolAction.signIn
                                  ? Icons.login_rounded
                                  : Icons.input_rounded,
                            ),
                      label: Text(
                        !_browserReady && _busy
                            ? '正在恢复登录…'
                            : _step == SchoolAction.signIn
                            ? (_busy
                                  ? '保存中…'
                                  : _importing
                                  ? '登录并继续'
                                  : '完成登录')
                            : (_busy ? '正在导入…' : '导入课表'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
