import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider_app/service/driver_api_service.dart';
import 'package:rider_app/service/location_consent_service.dart';
import 'package:rider_app/service/ride_alert_service.dart';
import 'package:rider_app/service/ride_picture_in_picture_service.dart';
import 'package:rider_app/service/ride_tracking/ride_distraction_guard.dart';
import 'package:rider_app/service/ride_tracking/ride_fix_filter.dart';
import 'package:rider_app/service/ride_tracking/ride_progress.dart';
import 'package:rider_app/service/ride_tracking/ride_tracking_repository.dart';
import 'package:rider_app/service/ride_tracking/tracked_fix.dart';

/// Owns live tracking for the ONE ride that is in progress.
///
/// Lifecycle rules (battery / policy safe):
///  * nothing runs until [start] (or [recoverIfNeeded]) is called,
///  * [stop] cancels the GPS stream, every timer, the notification and the
///    "zero distraction" flag. It is called when the ride completes, is
///    cancelled, the driver logs out, or the watchdog finds the ride is over,
///  * the controller belongs to the RIDE, not to a screen: leaving the
///    navigation screen does not stop it, finishing the ride does.
///
/// Screens only listen to [fixes] and [progress]; they never touch GPS.
class RideTrackingController with WidgetsBindingObserver {
  RideTrackingController._();
  static final RideTrackingController instance = RideTrackingController._();

  static const _sampleRideIds = {9901, 9902}; // testing rides: no backend
  static const _activeStatuses = {'accepted', 'in_progress', 'started'};

  final ValueNotifier<RideProgress> progress = ValueNotifier(
    const RideProgress(),
  );
  final StreamController<TrackedFix> _fixes =
      StreamController<TrackedFix>.broadcast();

  /// Cleaned positions, ready for the map marker.
  Stream<TrackedFix> get fixes => _fixes.stream;

  /// The newest accepted fix (null before the first one).
  TrackedFix? latest;

  int? _rideId;
  bool get isRunning => _rideId != null;
  int? get rideId => _rideId;

  RideTrackingRepository _repo = const GpsTrackingRepository();
  final RideFixFilter _filter = RideFixFilter();
  StreamSubscription<Position>? _posSub;
  StreamSubscription<ServiceStatus>? _serviceSub;
  Timer? _signalTimer;
  Timer? _watchdog;
  DateTime _lastFixAt = DateTime.now();
  DateTime _lastNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastNotifyText = '';
  double _smoothedSpeedMps = 0;
  bool _backgroundOk = true;
  bool _observing = false;
  bool _inBackground = false;

  // ---------------------------------------------------------------- start

  /// Starts (or updates) tracking for [rideId]. Safe to call repeatedly.
  /// Pass [repository] only for the debug simulation.
  Future<void> start({
    required int rideId,
    required RideLeg leg,
    LatLng? destination,
    String customerName = '',
    RideTrackingRepository? repository,
  }) async {
    final sameRide = _rideId == rideId;
    final newRepo = repository ?? const GpsTrackingRepository();
    final repoChanged = sameRide && newRepo.isSimulated != _repo.isSimulated;
    _rideId = rideId;
    _repo = newRepo;
    await RidePictureInPictureService.setRideActive(true);
    progress.value = progress.value.copyWith(
      leg: leg,
      destination: destination,
      customerName: customerName,
    );
    // A new simulated route (new leg) always restarts the stream; for real GPS
    // a repeated call only updates the target above.
    if (sameRide && !repoChanged && _posSub != null && repository == null) {
      return;
    }

    debugPrint(
      '[RIDE TRACK] start ride=$rideId leg=$leg sim=${_repo.isSimulated}',
    );
    await RideDistractionGuard.setActive(true);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _watchdog ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_verifyRideStillActive()),
    );
    _signalTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkSignal(),
    );
    if (!_repo.isSimulated) {
      _serviceSub ??= Geolocator.getServiceStatusStream().listen(
        (s) =>
            s == ServiceStatus.enabled ? unawaited(_openStream()) : _onGpsOff(),
        onError: (_) {},
      );
    }
    await _openStream();
  }

  /// Update where the vehicle is heading (pickup -> drop).
  void setTarget({required RideLeg leg, LatLng? destination}) {
    progress.value = progress.value.copyWith(
      leg: leg,
      destination: destination,
    );
  }

  // ----------------------------------------------------------------- stop

  /// Stops everything. Idempotent: calling it twice is harmless.
  Future<void> stop({String reason = ''}) async {
    if (_rideId == null && _posSub == null) return;
    debugPrint('[RIDE TRACK] stop ride=$_rideId reason=$reason');
    _rideId = null;
    await RidePictureInPictureService.setRideActive(false);
    await _closeStream();
    await _serviceSub?.cancel();
    _serviceSub = null;
    _signalTimer?.cancel();
    _signalTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    latest = null;
    _lastNotifyText = '';
    _smoothedSpeedMps = 0;
    progress.value = const RideProgress();
    await RideAlertService.cancelRideProgress();
    // Normal ride alerts come back; requests that arrived meanwhile were not
    // marked "seen", so the next poll alerts for them.
    await RideDistractionGuard.setActive(false);
  }

  /// After app restart / process death: if a ride was in progress, check the
  /// backend and resume tracking, or clean up if the ride is already over.
  Future<void> recoverIfNeeded() async {
    if (isRunning) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rideId = prefs.getInt('active_ride_id');
      final phone = prefs.getString('user_phone') ?? '';
      if (rideId == null || phone.isEmpty) {
        await RideDistractionGuard.setActive(false); // stale flag
        return;
      }
      final picked = prefs.getBool('active_ride_picked_up') ?? false;
      if (_sampleRideIds.contains(rideId))
        return; // screen restarts sample rides
      final ride = await DriverApiService.fetchRideDetail(
        rideId: rideId,
        driverPhone: phone,
      );
      final status = (ride['status'] ?? ride['ride_status'] ?? '').toString();
      if (!_activeStatuses.contains(status)) {
        await _clearRidePrefs();
        await RideDistractionGuard.setActive(false);
        return;
      }
      final leg = (picked || status == 'in_progress')
          ? RideLeg.toDrop
          : RideLeg.toPickup;
      final lat = _num(ride[leg == RideLeg.toDrop ? 'drop_lat' : 'pickup_lat']);
      final lng = _num(ride[leg == RideLeg.toDrop ? 'drop_lng' : 'pickup_lng']);
      await start(
        rideId: rideId,
        leg: leg,
        destination: (lat != null && lng != null) ? LatLng(lat, lng) : null,
        customerName: (ride['customer_name'] ?? '').toString(),
      );
    } catch (e) {
      // Offline at launch: keep the local flag, the watchdog retries later.
      debugPrint('[RIDE TRACK] recover failed (will retry): $e');
    }
  }

  /// The driver fixed GPS / permission from the banner: try again.
  Future<void> retry() async {
    if (isRunning) await _openStream();
  }

  // --------------------------------------------------------------- stream

  Future<void> _openStream() async {
    await _closeStream();
    if (_rideId == null) return;

    if (!_repo.isSimulated && !await _checkAccess()) return;

    _filter.reset();
    _lastFixAt = DateTime.now();
    _posSub = _repo.positions().listen(
      _onPosition,
      onError: (Object e) {
        debugPrint('[RIDE TRACK] stream error: $e');
        // Never crash the ride: retry shortly.
        _posSub?.cancel();
        _posSub = null;
        Future.delayed(const Duration(seconds: 5), () {
          if (isRunning && _posSub == null) unawaited(_openStream());
        });
      },
      cancelOnError: false,
    );
    if (!_repo.isSimulated) _startForegroundServiceIfAllowed();
  }

  Future<void> _closeStream() async {
    await _posSub?.cancel();
    _posSub = null;
  }

  /// Sets [TrackingStatus] for every way location can be unavailable.
  Future<bool> _checkAccess() async {
    if (!await LocationConsentService.hasAccepted()) {
      _setStatus(TrackingStatus.permissionDenied);
      return false;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      _onGpsOff();
      return false;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _setStatus(TrackingStatus.permissionBlocked);
      return false;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      _setStatus(TrackingStatus.permissionDenied);
      return false;
    }
    _backgroundOk = permission == LocationPermission.always;
    _setStatus(
      _backgroundOk ? TrackingStatus.ok : TrackingStatus.backgroundMissing,
    );
    return true;
  }

  void _onGpsOff() {
    _closeStream();
    _setStatus(TrackingStatus.gpsOff);
  }

  void _setStatus(TrackingStatus s) {
    if (progress.value.status == s) return;
    progress.value = progress.value.copyWith(status: s);
  }

  void _checkSignal() {
    if (!isRunning || _repo.isSimulated) return;
    final st = progress.value.status;
    final quiet = DateTime.now().difference(_lastFixAt);
    if (quiet > const Duration(seconds: 20) &&
        (st == TrackingStatus.ok || st == TrackingStatus.backgroundMissing)) {
      _setStatus(TrackingStatus.noSignal);
    }
  }

  // ------------------------------------------------------------- positions

  void _onPosition(Position raw) {
    final fix = _filter.accept(raw, simulated: _repo.isSimulated);
    if (fix == null) return;
    _lastFixAt = DateTime.now();
    latest = fix;

    _smoothedSpeedMps = _smoothedSpeedMps == 0
        ? fix.position.speed.clamp(0, 70).toDouble()
        : _smoothedSpeedMps * 0.7 +
              fix.position.speed.clamp(0, 70).toDouble() * 0.3;

    final p = progress.value;
    final dest = p.destination;
    double? meters;
    int? eta;
    if (dest != null) {
      meters = Geolocator.distanceBetween(
        fix.position.latitude,
        fix.position.longitude,
        dest.latitude,
        dest.longitude,
      );
      // Straight line x 1.3 approximates the road; never assume faster than
      // 25 km/h or slower than the real speed, so the ETA does not explode
      // at a signal.
      final mps = _smoothedSpeedMps > 7 ? _smoothedSpeedMps : 7.0;
      eta = ((meters * 1.3) / mps / 60).ceil().clamp(1, 240);
    }
    final okStatus = _backgroundOk
        ? TrackingStatus.ok
        : TrackingStatus.backgroundMissing;
    progress.value = p.copyWith(
      status: okStatus,
      remainingMeters: meters,
      etaMinutes: eta,
      speedKmh: fix.speedKmh,
      moving: !fix.stationary && fix.speedKmh > 0,
    );
    if (!_fixes.isClosed) _fixes.add(fix);
    _notify();
  }

  // ---------------------------------------------------------- notification

  /// "Head to pickup - 4 min" / "1.8 km left - 32 km/h". Updated at most every
  /// 5 s and only when the text changes, so it never spams the service.
  void _notify({bool force = false}) {
    if (!isRunning) return;
    if (Platform.isIOS && !_inBackground) return; // iOS: only when minimized
    final p = progress.value;
    final title = '${p.instruction} • ${p.etaText}';
    final who = p.customerName.isEmpty ? '' : ' • ${p.customerName}';
    final body = '${p.distanceText} left • ${p.speedText}$who';
    final text = '$title|$body';
    final now = DateTime.now();
    if (!force &&
        (text == _lastNotifyText ||
            now.difference(_lastNotifyAt) < const Duration(seconds: 5))) {
      return;
    }
    _lastNotifyText = text;
    _lastNotifyAt = now;
    unawaited(RideAlertService.showRideProgress(title: title, body: body));
  }

  void _startForegroundServiceIfAllowed() {
    if (!Platform.isAndroid) return;
    // Android 12+ refuses to start a foreground service from the background,
    // and Android 14+ also needs location permission first. Both are true
    // when a ride starts from the screen; otherwise skip safely.
    final resumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!resumed) return;
    unawaited(RideAlertService.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isRunning) return;
    if (state == AppLifecycleState.paused) {
      _inBackground = true;
      if (Platform.isIOS) _notify(force: true);
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      if (Platform.isIOS) unawaited(RideAlertService.cancelRideProgress());
      // Permission or GPS may have been fixed in Settings meanwhile.
      if (progress.value.status != TrackingStatus.ok) unawaited(_openStream());
    }
  }

  // -------------------------------------------------------------- watchdog

  /// Safety net so tracking can never outlive the ride (cancelled from the
  /// customer side, completed elsewhere, logout, cleared prefs).
  Future<void> _verifyRideStillActive() async {
    final id = _rideId;
    if (id == null) return;
    if (_sampleRideIds.contains(id)) return; // local only, no backend
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('active_ride_id') != id) {
      await stop(reason: 'active_ride_id cleared');
      return;
    }
    final phone = prefs.getString('user_phone') ?? '';
    if (phone.isEmpty || prefs.getBool('isLoggedIn') == false) {
      await stop(reason: 'logged out');
      return;
    }
    try {
      final ride = await DriverApiService.fetchRideDetail(
        rideId: id,
        driverPhone: phone,
      );
      final status = (ride['status'] ?? ride['ride_status'] ?? '').toString();
      if (status.isNotEmpty && !_activeStatuses.contains(status)) {
        await _clearRidePrefs();
        await stop(reason: 'backend status=$status');
      }
    } catch (_) {
      // Network down: keep tracking, try again in 45 s.
    }
  }

  Future<void> _clearRidePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_ride_id');
    await prefs.remove('active_ride_picked_up');
  }

  double? _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}
