import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map marker pictures drawn in code (Ola / Uber style), cached after the
/// first use.
class MapIcons {
  MapIcons._();

  static BitmapDescriptor? _driver;
  static BitmapDescriptor? _rider;
  static BitmapDescriptor? _drop;

  /// The driver: a blue arrow in a white ring. The map turns it to face the
  /// way the vehicle is moving.
  static Future<BitmapDescriptor> driver() async {
    return _driver ??= await _draw(72, 36, (canvas) {
      const c = Offset(36, 36);
      canvas.drawCircle(c, 30, Paint()..color = const Color(0x332563EB));
      canvas.drawCircle(c, 22, Paint()..color = Colors.white);
      final arrow = Path()
        ..moveTo(36, 14)
        ..lineTo(48, 50)
        ..lineTo(36, 42)
        ..lineTo(24, 50)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0xFF1D4ED8));
    });
  }

  /// The rider waiting at the pickup point: a green pin with a person inside.
  static Future<BitmapDescriptor> rider() async {
    return _rider ??= await _pin(const Color(0xFF16A34A), Icons.person_rounded);
  }

  /// The drop point: a red pin with a flag inside.
  static Future<BitmapDescriptor> drop() async {
    return _drop ??= await _pin(const Color(0xFFEA4335), Icons.flag_rounded);
  }

  static Future<BitmapDescriptor> _pin(Color color, IconData icon) {
    return _draw(80, 40, (canvas) {
      final path = Path()
        ..moveTo(40, 76)
        ..quadraticBezierTo(14, 46, 14, 30)
        ..arcToPoint(
          const Offset(66, 30),
          radius: const Radius.circular(26),
          clockwise: true,
        )
        ..quadraticBezierTo(66, 46, 40, 76)
        ..close();
      canvas.drawShadow(path, Colors.black, 3, true);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawCircle(
        const Offset(40, 30),
        17,
        Paint()..color = Colors.white,
      );
      final glyph = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 24,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, Offset(40 - glyph.width / 2, 30 - glyph.height / 2));
    });
  }

  /// [size] pixels square, drawn at [logical] logical pixels on the map.
  static Future<BitmapDescriptor> _draw(
    int size,
    double logical,
    void Function(Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: size / logical,
    );
  }
}
