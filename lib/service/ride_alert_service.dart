import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_app/service/api_client.dart';
import 'package:rider_app/service/token_store.dart';
import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/common/routes/app_router.dart';
import 'package:rider_app/common/routes/app_routes.dart';
import 'package:rider_app/service/ride_tracking/ride_distraction_guard.dart';

/// Keeps polling for rides while the driver is online, even if the UI is closed.
/// Shows a high-priority local notification with the custom ride alert sound.
class RideAlertService {
  static const String rideChannelId = 'ride_requests';
  static const String onlineChannelId = 'driver_online';
  static const int rideNotificationId = 4401;
  static const int onlineNotificationId = 888;
  static const int rideProgressIosNotificationId = 4402;
  static const String activeRidePayload = 'active_ride';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    // Permission prompts are NOT shown here: StartupPermissions asks for
    // notifications first and location second, after the first frame.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      // Tapping the ongoing ride notification returns to the live ride screen.
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == activeRidePayload) {
          AppRouter.router.go(AppRoutes.navigation);
        }
      },
    );

    // Only configure the background service daemon on Android.
    // On iOS, background isolates cannot sustain arbitrary polling and trigger
    // "Communicating on a dead channel" loops on hot restart.
    if (!Platform.isAndroid) return;

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        rideChannelId,
        'Ride Requests',
        description: 'Alerts when a new ride request arrives',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ride_alert'),
        enableVibration: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        onlineChannelId,
        'Driver Online',
        description: 'Shown while you are online and searching for rides',
        importance: Importance.low,
      ),
    );

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: onlineChannelId,
        initialNotificationTitle: 'TORKK Driver',
        initialNotificationContent: 'Searching for rides...',
        foregroundServiceNotificationId: onlineNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBackgroundStart,
      ),
    );
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (!running) {
        await service.startService();
      } else {
        service.invoke('refresh');
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      await _notifications.cancel(id: rideNotificationId);
      return;
    }
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (running) {
        service.invoke('stop');
      }
    } catch (_) {}
    await _notifications.cancel(id: rideNotificationId);
  }

  /// Ongoing ride card: instruction + ETA + distance + speed.
  ///
  /// Android: replaces the foreground-service notification (same id), so there
  /// is one persistent card, not two. iOS cannot keep an ongoing notification;
  /// a quiet one is shown only while the app is minimized.
  static Future<void> showRideProgress({
    required String title,
    required String body,
  }) async {
    final details = Platform.isAndroid
        ? NotificationDetails(
            android: AndroidNotificationDetails(
              onlineChannelId,
              'Driver Online',
              channelDescription: 'Shown while you are online',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              onlyAlertOnce: true,
              autoCancel: false,
              playSound: false,
              enableVibration: false,
              category: AndroidNotificationCategory.navigation,
              visibility: NotificationVisibility.public,
              styleInformation: BigTextStyleInformation(body),
            ),
          )
        : const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentSound: false,
              presentBadge: false,
              interruptionLevel: InterruptionLevel.passive,
            ),
          );
    try {
      await _notifications.show(
        id: Platform.isAndroid
            ? onlineNotificationId
            : rideProgressIosNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: activeRidePayload,
      );
    } catch (e) {
      debugPrint('[RideAlertService] progress notification failed: $e');
    }
  }

  /// Removes the ride card. On Android the foreground-service notification
  /// goes away with the service; this resets its text for the next use.
  static Future<void> cancelRideProgress() async {
    try {
      if (Platform.isIOS) {
        await _notifications.cancel(id: rideProgressIosNotificationId);
      } else if (Platform.isAndroid) {
        await _notifications.show(
          id: onlineNotificationId,
          title: 'TORKK Driver',
          body: 'Searching for rides...',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              onlineChannelId,
              'Driver Online',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              onlyAlertOnce: true,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  static Future<void> showNewRideNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Zero distraction: no ride-request alerts while a ride is in progress.
    if (await RideDistractionGuard.isActive()) {
      debugPrint('[RideAlertService] suppressed: ride in progress');
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        rideChannelId,
        'Ride Requests',
        channelDescription: 'Alerts when a new ride request arrives',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ride_alert'),
        enableVibration: true,
        category: AndroidNotificationCategory.event,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
      ),
    );
    await _notifications.show(
      id: rideNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}

/// Stops the background service from inside itself. (`service.invoke('stop')`
/// would only message the UI isolate and leave the service running.)
void _stopSelf(ServiceInstance service) {
  try {
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    } else {
      service.invoke('stop');
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _onBackgroundStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  const iosInit = DarwinInitializationSettings();
  await notifications.initialize(
    settings: const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  final knownRideIds = <int>{};
  var seeded = false;

  Future<void> poll() async {
    try {
      // TokenStore.read() reloads the prefs, so read it BEFORE the other keys.
      final token = await TokenStore.read();
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? '';
      final isOnline = prefs.getBool('driver_is_online') ?? false;
      // No login token = nobody is logged in. Polling without one only collects
      // 401s (which used to log the driver out right after a fresh login), so
      // stop the service instead.
      if (token.isEmpty || !(prefs.getBool('isLoggedIn') ?? false)) {
        debugPrint('[RideAlertService] no login token, stopping the service');
        _stopSelf(service);
        return;
      }

      final rideActive = await RideDistractionGuard.isActive();
      if (rideActive) {
        // Mid-ride: keep the service (and its ride card) alive, but do not
        // poll for new requests or alert.
        return;
      }
      if (!isOnline || phone.isEmpty) {
        _stopSelf(service);
        return;
      }

      final uri = Uri.parse(AppUrls.activeRides(driverPhone: phone));
      final response = await apiClient.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data is! List) return;

      final currentIds = <int>{};
      String? pickupHint;
      for (final ride in data) {
        if (ride is! Map) continue;
        if ((ride['status'] ?? '').toString() != 'requested') continue;
        final idVal = ride['id'];
        final id = idVal is int ? idVal : int.tryParse('$idVal');
        if (id == null) continue;
        currentIds.add(id);
        pickupHint ??=
            (ride['pickup_address'] ?? ride['pickup'] ?? 'Nearby pickup')
                .toString();
      }

      if (!seeded) {
        knownRideIds
          ..clear()
          ..addAll(currentIds);
        seeded = true;
        return;
      }

      final brandNew = currentIds.difference(knownRideIds);
      knownRideIds
        ..clear()
        ..addAll(currentIds);

      if (brandNew.isEmpty) return;

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          RideAlertService.rideChannelId,
          'Ride Requests',
          channelDescription: 'Alerts when a new ride request arrives',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('ride_alert'),
          enableVibration: true,
          category: AndroidNotificationCategory.event,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
        ),
      );

      await notifications.show(
        id: RideAlertService.rideNotificationId,
        title: 'New ride request',
        body: pickupHint == null || pickupHint.isEmpty
            ? 'Open TORKK Driver to accept the ride'
            : 'Pickup: $pickupHint',
        notificationDetails: details,
        payload: 'new_ride',
      );
    } catch (e) {
      debugPrint('[RideAlertService] poll error: $e');
    }
  }

  if (service is AndroidServiceInstance) {
    service.on('stop').listen((event) {
      service.stopSelf();
    });
    service.setAsForegroundService();
  } else {
    service.on('stop').listen((event) {
      service.stopSelf();
    });
  }

  service.on('refresh').listen((event) {
    seeded = false;
    knownRideIds.clear();
  });

  Timer.periodic(const Duration(seconds: 4), (_) {
    unawaited(poll());
  });
  await poll();
}
