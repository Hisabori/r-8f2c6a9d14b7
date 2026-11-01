import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeModules {
  static const channel = MethodChannel('app.caresuite/native');
  static bool get supported => defaultTargetPlatform == TargetPlatform.iOS;
  static Future<bool> open(String module) async {
    if (!['health', 'crypto'].contains(module)) {
      throw ArgumentError.value(module);
    }
    if (!supported) return false;
    return await channel.invokeMethod<bool>('open', {'module': module}) ??
        false;
  }

  static Future<void> ready() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      /* Tests and unconfigured hosts. */
    }
  }
}
