import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rider_app/app/app_bootstrap.dart';
import 'package:rider_app/app/driver_app.dart';

Future<void> main() async {
  // A release build prints nothing: print() and debugPrint() lines would put
  // phone numbers, ride details and similar into the device log.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  await runZoned<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final themeRepository = await AppBootstrap.start();
      runApp(DriverApp(themeRepository: themeRepository));
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!kReleaseMode) parent.print(zone, line);
      },
    ),
  );
}
