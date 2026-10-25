import 'dart:io';
import 'package:flutter/services.dart';

Future<void> updateDesktopWidget() async {
  if (Platform.isAndroid) {
    await const MethodChannel(
      'dev.so1ve.bitree/widget',
    ).invokeMethod<void>('update');
  }
}
