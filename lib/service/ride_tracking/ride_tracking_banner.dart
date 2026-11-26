import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:rider_app/service/location_permission_flow.dart';
import 'package:rider_app/service/ride_tracking/ride_progress.dart';
import 'package:rider_app/service/ride_tracking/ride_tracking_controller.dart';

/// Shows a clear message + one-tap fix when live tracking cannot run
/// (GPS off, permission denied or blocked, only "while in use", no signal).
/// Draws nothing while everything is fine. The ride itself keeps working.
class RideTrackingBanner extends StatelessWidget {
  const RideTrackingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RideTrackingController.instance;
    return ValueListenableBuilder<RideProgress>(
      valueListenable: controller.progress,
      builder: (context, p, _) {
        final spec = _spec(p.status);
        if (spec == null) return const SizedBox.shrink();
        return Material(
          color: spec.color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: spec.action == null ? null : () => spec.action!(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(spec.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      spec.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (spec.button != null)
                    Text(
                      spec.button!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _BannerSpec? _spec(TrackingStatus s) {
    switch (s) {
      case TrackingStatus.idle:
      case TrackingStatus.ok:
        return null;
      case TrackingStatus.gpsOff:
        return _BannerSpec(
          Icons.location_off_rounded,
          'GPS is off. Turn it on to track this ride.',
          const Color(0xFFDC2626),
          'Turn on',
          (_) async {
            await Geolocator.openLocationSettings();
            await RideTrackingController.instance.retry();
          },
        );
      case TrackingStatus.permissionDenied:
        return _BannerSpec(
          Icons.my_location_rounded,
          'Allow location to track this ride.',
          const Color(0xFFDC2626),
          'Allow',
          (context) async {
            await LocationPermissionFlow.ensure(context, background: true);
            await RideTrackingController.instance.retry();
          },
        );
      case TrackingStatus.permissionBlocked:
        return _BannerSpec(
          Icons.lock_outline_rounded,
          'Location is blocked. Open Settings and allow it for TORKK.',
          const Color(0xFFDC2626),
          'Settings',
          (_) => Geolocator.openAppSettings(),
        );
      case TrackingStatus.backgroundMissing:
        return _BannerSpec(
          Icons.info_outline_rounded,
          'Choose "Always" so the ride keeps tracking when you switch apps.',
          const Color(0xFFD97706),
          'Allow',
          (context) async {
            final access = await LocationPermissionFlow.ensure(
              context,
              background: true,
              force: true,
            );
            if (access != LocationAccess.background) {
              // The OS only shows the "Always" prompt once on some versions.
              await Geolocator.openAppSettings();
            }
            await RideTrackingController.instance.retry();
          },
        );
      case TrackingStatus.noSignal:
        return _BannerSpec(
          Icons.signal_cellular_connected_no_internet_0_bar_rounded,
          'Weak GPS signal. Position will update when it returns.',
          const Color(0xFF6B7280),
          null,
          null,
        );
    }
  }
}

class _BannerSpec {
  const _BannerSpec(this.icon, this.text, this.color, this.button, this.action);
  final IconData icon;
  final String text;
  final Color color;
  final String? button;
  final Future<void> Function(BuildContext context)? action;
}
