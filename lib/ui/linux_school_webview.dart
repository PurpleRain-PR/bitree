import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/school_session.dart';

const schoolBrowserChannel = MethodChannel('dev.so1ve.bitree/school_browser');

class LinuxSchoolBrowser {
  Future<void> restoreCookie(Uri source, Cookie cookie) =>
      schoolBrowserChannel.invokeMethod('restoreCookie', {
        'url': source.toString(),
        'name': cookie.name,
        'value': cookie.value,
        'domain': cookie.domain ?? source.host,
        'path': cookie.path ?? '/',
        'secure': cookie.secure,
        'httpOnly': cookie.httpOnly,
        'expires': cookie.expires == null
            ? null
            : cookie.expires!.millisecondsSinceEpoch ~/ 1000,
      });

  Future<void> load(Uri url) =>
      schoolBrowserChannel.invokeMethod('load', url.toString());

  Future<Object?> run(String body) async {
    final result = await schoolBrowserChannel.invokeMethod<String>(
      'javascript',
      body,
    );
    return result == null ? null : jsonDecode(result);
  }

  Future<List<Cookie>> cookies(Uri source) async {
    final values =
        await schoolBrowserChannel.invokeListMethod<Map>(
          'cookies',
          source.toString(),
        ) ??
        [];
    return values.map((value) {
      final cookie = Cookie(value['name'] as String, value['value'] as String)
        ..domain = value['domain'] as String
        ..path = value['path'] as String
        ..secure = value['secure'] as bool
        ..httpOnly = value['httpOnly'] as bool;
      if (value['expires'] != null) {
        cookie.expires = DateTime.fromMillisecondsSinceEpoch(
          (value['expires'] as int) * 1000,
          isUtc: true,
        );
      }
      return cookie;
    }).toList();
  }
}

class LinuxSchoolWebView extends StatefulWidget {
  const LinuxSchoolWebView({
    super.key,
    required this.initialUrl,
    required this.onCreated,
    required this.onLoadStart,
    required this.onLoadStop,
    required this.onProgress,
    required this.onError,
  });

  final Uri initialUrl;
  final ValueChanged<LinuxSchoolBrowser> onCreated;
  final ValueChanged<Uri> onLoadStart;
  final ValueChanged<Uri> onLoadStop;
  final ValueChanged<double> onProgress;
  final ValueChanged<String> onError;

  @override
  State<LinuxSchoolWebView> createState() => _LinuxSchoolWebViewState();
}

class _LinuxSchoolWebViewState extends State<LinuxSchoolWebView>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _queued = false;
  (Rect, Size)? _bounds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    schoolBrowserChannel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'loadStart':
          widget.onLoadStart(Uri.parse(call.arguments as String));
        case 'loadStop':
          widget.onLoadStop(Uri.parse(call.arguments as String));
        case 'progress':
          widget.onProgress((call.arguments as num).toDouble());
        case 'error':
          widget.onError(call.arguments as String);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      widget.onCreated(LinuxSchoolBrowser());
      try {
        await schoolBrowserChannel.invokeMethod('create', {
          'url': widget.initialUrl.toString(),
          'userAgent': SchoolSession.userAgent,
        });
        if (!mounted) return;
        _ready = true;
        _scheduleBounds();
      } catch (error) {
        if (mounted) widget.onError(operationMessage(error));
      }
    });
  }

  String operationMessage(Object error) => error is PlatformException
      ? (error.message ?? '无法打开学校网页，请重试。')
      : '无法打开学校网页：$error';

  void _scheduleBounds() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_ready) return;
      final box = context.findRenderObject() as RenderBox;
      if (!box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final view = View.of(context);
      final size = view.physicalSize / view.devicePixelRatio;
      if (_bounds == (rect, size)) return;
      _bounds = (rect, size);
      unawaited(
        schoolBrowserChannel.invokeMethod('bounds', {
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
          'viewWidth': size.width,
          'viewHeight': size.height,
        }),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeMetrics() => _scheduleBounds();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    schoolBrowserChannel.setMethodCallHandler(null);
    unawaited(schoolBrowserChannel.invokeMethod('dispose'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _scheduleBounds();
      return const SizedBox.expand();
    },
  );
}
