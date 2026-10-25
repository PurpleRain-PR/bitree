import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Future<void> clearBrowserSession() async {
  if (Platform.isLinux) {
    await const MethodChannel(
      'dev.so1ve.bitree/school_browser',
    ).invokeMethod('clearCookies');
  } else {
    await CookieManager.instance().deleteAllCookies();
  }
}
