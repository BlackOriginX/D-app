import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RidePictureInPictureService {
  RidePictureInPictureService._();

  static const MethodChannel _channel = MethodChannel(
    'com.blackoriginx.torkkdriver/pip',
  );
  static final ValueNotifier<bool> isInPictureInPicture = ValueNotifier(false);
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pictureInPictureChanged') {
        isInPictureInPicture.value = call.arguments == true;
      }
    });
  }

  static Future<void> setRideActive(bool active) async {
    if (!Platform.isAndroid) return;
    initialize();
    try {
      await _channel.invokeMethod<void>('setRideActive', <String, bool>{
        'active': active,
      });
    } on PlatformException catch (error) {
      debugPrint('[RIDE PIP] Could not update Android PiP state: $error');
    }
  }
}
