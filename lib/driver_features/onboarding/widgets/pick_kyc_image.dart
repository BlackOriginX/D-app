import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/constants/string_constants.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/utils/screen_utils.dart';

/// Asks Camera or Gallery, then returns the picked photo path (null if the
/// driver cancels or the picker fails).
Future<String?> pickKycImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: context.torkk.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(context.r(16))),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: context.legible(AppColors.primary),
              ),
              title: Text(
                AppStrings.camera,
                style: AppTypography.bold.copyWith(fontSize: 15),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_outlined,
                color: context.legible(AppColors.primary),
              ),
              title: Text(
                AppStrings.gallery,
                style: AppTypography.bold.copyWith(fontSize: 15),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
  if (source == null) return null;
  try {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    return photo?.path;
  } catch (e) {
    debugPrint('[KYC PICK IMAGE] failed: $e');
    return null;
  }
}
