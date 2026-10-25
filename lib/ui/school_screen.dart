import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../data/school_errors.dart';
import '../data/school_network.dart';
import '../data/school_page.dart';
import '../error_message.dart';
import 'school_network_picker.dart';
import 'school_webview.dart';

enum SchoolAction { signIn, importSchedule }

Future<bool?> openSchoolPage(
  BuildContext context,
  AppController controller, {
  required SchoolAction action,
}) async {
  if (controller.busy) return null;
  final switching =
      action == SchoolAction.signIn &&
      controller.accountStatus == AccountStatus.signedIn;
  final title = switch (action) {
    SchoolAction.importSchedule => '导入课表',
    SchoolAction.signIn => switching ? '切换登录方式' : '登录账号',
  };
  final network = await pickSchoolNetwork(
    context,
    title: title,
    current: switching ? controller.network : null,
  );
  if (network == null || !context.mounted || controller.busy) return null;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _SchoolScreen(
        controller: controller,
        network: network,
        action: action,
      ),
    ),
  );
}

class _SchoolScreen extends StatefulWidget {
  const _SchoolScreen({
    required this.controller,
    required this.network,
    required this.action,
  });

  final AppController controller;
  final SchoolNetwork network;
  final SchoolAction action;

  @override
  State<_SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<_SchoolScreen> {
  SchoolNetwork get _network => widget.network;

  bool get _active => mounted && ModalRoute.of(context)!.isCurrent;

  bool get _importing => widget.action == SchoolAction.importSchedule;
  late SchoolAction _step;
  late final Uri _initialUrl;
  bool _sessionRestored = false;
  final _browser = SchoolBrowser();
  late final _page = SchoolPage(network: _network, evaluate: _browser.run);
  bool _busy = false;
  bool _gatewayOpened = false;
  bool _courseOpened = false;
  double _progress = 0;
  String? _error;

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
      await _browser.restoreSession(widget.controller.schoolSession, _network);
      if (mounted) setState(() => _sessionRestored = true);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _loadStarted(Uri url) {
    if (!_active) return;
    setState(() {
      _progress = 0;
      _error = null;
      if (isSchoolLogin(url)) _step = SchoolAction.signIn;
    });
    if (isSchoolLogin(url) && widget.controller.network == _network) {
      widget.controller.requireLogin();
    }
  }

  Future<void> _pageLoaded(Uri url) async {
    if (!_active) return;
    try {
      if (_step == SchoolAction.signIn) {
        if (_network.isLoginLanding(url)) await _finish();
        return;
      }
      if (_network.isGatewayHome(url) && !_gatewayOpened) {
        _gatewayOpened = true;
        await _browser.navigate(SchoolNetwork.webvpnTeachingLogin);
      } else if (_network.isAuthLanding(url) && !_courseOpened) {
        _courseOpened = true;
        await _browser.navigate(_network.app);
      }
      // Course data is read only when the user presses the import button.
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  Future<void> _restart() async {
    setState(() {
      _gatewayOpened = false;
      _courseOpened = false;
      _error = null;
    });
    if (!_sessionRestored) {
      await _restoreSession();
      return;
    }
    try {
      await _browser.load(
        _step == SchoolAction.signIn ? _network.loginEntry : _network.app,
      );
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  Future<void> _finish() async {
    if (_busy || !_sessionRestored || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signingIn = _step == SchoolAction.signIn;
      if (signingIn) {
        await _page.checkLogin();
      } else {
        await _page.checkSchedule();
      }
      await _browser.captureSession(widget.controller.schoolSession, _network);
      if (!_active) return;
      final success = signingIn
          ? await widget.controller.completeSignIn(_network)
          : await widget.controller.synchronize(
              using: _network,
              request: _page.json,
            );
      if (!mounted || !ModalRoute.of(context)!.isCurrent) return;
      if (success) {
        if (signingIn && _importing) {
          setState(() {
            _step = SchoolAction.importSchedule;
            _gatewayOpened = false;
            _courseOpened = false;
          });
          await _browser.navigate(
            _network == SchoolNetwork.webvpn
                ? SchoolNetwork.webvpnTeachingLogin
                : _network.app,
          );
        } else {
          Navigator.of(context).pop(true);
        }
      } else if (!signingIn && widget.controller.loginExpired) {
        await _loginAgain();
      } else {
        setState(() => _error = widget.controller.error);
      }
    } on SessionExpired {
      if (widget.controller.network == _network) {
        widget.controller.requireLogin();
      }
      if (mounted) {
        if (_step == SchoolAction.importSchedule) {
          await _loginAgain();
        } else {
          setState(() => _error = schoolLoginNotReady);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
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
      await _browser.load(_network.loginEntry);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  String get _actionLabel {
    if (!_sessionRestored && _busy) return '正在恢复登录…';
    if (_step == SchoolAction.importSchedule) {
      return _busy ? '正在导入…' : '导入课表';
    }
    if (_busy) return '保存中…';

    return _importing ? '登录并继续' : '完成登录';
  }

  Widget _buildBrowser() {
    if (!_sessionRestored) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : TextButton(onPressed: _restoreSession, child: const Text('重试')),
      );
    }

    return SchoolWebView(
      controller: _browser,
      initialUrl: _initialUrl,
      onLoadStart: _loadStarted,
      onLoadStop: _pageLoaded,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
      onError: (value) {
        if (mounted) setState(() => _error = value);
      },
    );
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
            Expanded(child: _buildBrowser()),
            const Divider(height: 1),
            Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
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
                          onPressed: _busy || !_sessionRestored
                              ? null
                              : _finish,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _step == SchoolAction.signIn
                                      ? Icons.login_rounded
                                      : Icons.input_rounded,
                                ),
                          label: Text(_actionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
