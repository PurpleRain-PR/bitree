package dev.so1ve.bitree

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.so1ve.bitree/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    TimetableWidget.updateAll(this)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
