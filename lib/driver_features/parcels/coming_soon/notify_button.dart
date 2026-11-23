import 'package:flutter/material.dart';
import 'package:rider_app/common/widgets/t_text.dart';

/// Coming Soon screens keep the design's own purple; they do not follow the
/// gender-based accent used in the rest of the app.
const Color _comingSoonPurple = Color(0xFF42145A);

class NotifyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const NotifyButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const fill = _comingSoonPurple;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: fill,
          disabledBackgroundColor: fill,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TText(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
