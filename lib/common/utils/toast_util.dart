import 'package:flutter/material.dart';

import 'package:rider_app/common/widgets/t_text.dart';

class ToastUtil {
  static void show(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TText(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
