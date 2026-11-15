part of 'package:rider_app/driver_features/onboarding/screens/face_verification_screen.dart';

class _VerifyingFace extends StatefulWidget {
  const _VerifyingFace({required this.selfiePath, required this.onFinished});

  final String? selfiePath;

  /// Called once with null when the face is verified, or the error message.
  final ValueChanged<String?> onFinished;

  @override
  State<_VerifyingFace> createState() => _VerifyingFaceState();
}
