import 'dart:io';

import 'package:flutter/material.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/constants/string_constants.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/driver_features/onboarding/widgets/kyc_form_widgets.dart';
import 'package:rider_app/common/widgets/app_text_field.dart';
import 'package:rider_app/common/widgets/onboarding_info_banner.dart';
import 'package:rider_app/common/widgets/onboarding_step_scaffold.dart';
import 'package:rider_app/common/widgets/unified_button.dart';
import 'package:rider_app/driver_features/onboarding/kyc_documents_api.dart';
import 'package:rider_app/driver_features/onboarding/widgets/pick_kyc_image.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';

part 'vehicle_photos_screen_parts/photo_result_card.dart';
part 'vehicle_photos_screen_parts/type_chip.dart';
part 'vehicle_photos_screen_sections.dart';

enum _PhotoPage { details, uploading, action, verified }

class VehiclePhotosScreen extends StatefulWidget {
  const VehiclePhotosScreen({
    super.key,
    required this.onBack,
    required this.onHelp,
    required this.onFinished,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onFinished;

  @override
  State<VehiclePhotosScreen> createState() => _VehiclePhotosScreenState();
}

class _VehiclePhotosScreenState extends State<VehiclePhotosScreen> {
  static const _types = ['Cab', 'Auto', 'Car'];

  _PhotoPage _page = _PhotoPage.details;
  String? _frontPath;
  String? _backPath;
  // Links of photos the server already holds (from GET vehicle/photos).
  String _frontUrl = '';
  String _backUrl = '';
  String _type = '';
  String? _error;
  final _numberController = TextEditingController();
  final _modelController = TextEditingController();

  bool get _hasFront => _frontPath != null || _frontUrl.isNotEmpty;
  bool get _hasBack => _backPath != null || _backUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// Fills the form from the vehicle saved earlier (GET vehicle/info) and
  /// picks up photos already uploaded (GET vehicle/photos). Failures are
  /// ignored: the driver can simply type the details.
  Future<void> _prefill() async {
    try {
      final info = await KycDocumentsApi.fetchVehicleInfo();
      if (!mounted) return;
      setState(() {
        if (_numberController.text.isEmpty) {
          _numberController.text = info.registrationNumber;
        }
        if (_modelController.text.isEmpty) {
          _modelController.text = info.model;
        }
        if (_type.isEmpty) {
          for (final type in _types) {
            if (type.toLowerCase() == info.type.toLowerCase()) _type = type;
          }
        }
      });
    } on KycApiException {
      // Optional prefill only.
    }
    try {
      final photos = await KycDocumentsApi.fetchVehiclePhotos();
      if (!mounted) return;
      setState(() {
        _frontUrl = photos.front;
        _backUrl = photos.back;
      });
    } on KycApiException {
      // Nothing uploaded yet.
    }
  }

  void _go(_PhotoPage page) => setState(() => _page = page);

  Future<void> _pick({required bool front}) async {
    final path = await pickKycImage(context);
    if (path == null || !mounted) return;
    setState(() {
      if (front) {
        _frontPath = path;
      } else {
        _backPath = path;
      }
    });
  }

  String? _validate() {
    if (!_hasFront || !_hasBack) return 'Add both front and back photos.';
    if (_numberController.text.trim().isEmpty) {
      return 'Enter the registration number.';
    }
    if (_modelController.text.trim().isEmpty) return 'Enter the vehicle model.';
    if (_type.isEmpty) return 'Select the vehicle type.';
    return null;
  }

  /// Continue: POST both photos with the details. If the server already holds
  /// one side, only the newly chosen side is sent with PUT.
  Future<void> _upload() async {
    final problem = _validate();
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() {
      _error = null;
      _page = _PhotoPage.uploading;
    });
    try {
      final front = _frontPath;
      final back = _backPath;
      if (front != null && back != null) {
        await KycDocumentsApi.uploadVehiclePhotos(
          frontPath: front,
          backPath: back,
          rcNumber: _numberController.text.trim().toUpperCase(),
          vehicleModel: _modelController.text.trim(),
          vehicleType: _type,
        );
      } else {
        if (front != null) {
          await KycDocumentsApi.replaceVehiclePhoto(type: 'front', path: front);
        }
        if (back != null) {
          await KycDocumentsApi.replaceVehiclePhoto(type: 'back', path: back);
        }
      }
      if (mounted) _go(_PhotoPage.verified);
    } on KycApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _page = _PhotoPage.action;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _PhotoPage.details => _details(context),
      _PhotoPage.uploading => _uploading(context),
      _PhotoPage.action => _action(context),
      _PhotoPage.verified => _verified(context),
    };
  }

  Widget _details(BuildContext context) {
    return OnboardingStepScaffold(
      title: AppStrings.vehicleDetails,
      onBack: widget.onBack,
      onHelp: widget.onHelp,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.w(24),
          context.h(8),
          context.w(24),
          context.h(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.uploadVehiclePhoto,
              style: AppTypography.bold.copyWith(fontSize: 14, height: 1.2),
            ),
            SizedBox(height: context.h(10)),
            Row(
              children: [
                Expanded(
                  child: KycUploadTile(
                    label: AppStrings.frontSide,
                    uploaded: _hasFront,
                    imagePath: _frontPath,
                    imageUrl: _frontPath == null && _frontUrl.isNotEmpty
                        ? _frontUrl
                        : null,
                    onTap: () => _pick(front: true),
                  ),
                ),
                SizedBox(width: context.w(12)),
                Expanded(
                  child: KycUploadTile(
                    label: AppStrings.backSide,
                    uploaded: _hasBack,
                    imagePath: _backPath,
                    imageUrl: _backPath == null && _backUrl.isNotEmpty
                        ? _backUrl
                        : null,
                    onTap: () => _pick(front: false),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(16)),
            KycRequiredLabel(AppStrings.registrationNumber),
            SizedBox(height: context.h(8)),
            AppTextField(controller: _numberController),
            SizedBox(height: context.h(14)),
            KycRequiredLabel(AppStrings.vehicleModel),
            SizedBox(height: context.h(8)),
            AppTextField(controller: _modelController),
            SizedBox(height: context.h(14)),
            KycRequiredLabel(AppStrings.vehicleType),
            SizedBox(height: context.h(8)),
            Row(
              children: [
                for (final type in _types) ...[
                  _TypeChip(
                    label: type,
                    selected: _type == type,
                    onTap: () => setState(() => _type = type),
                  ),
                  SizedBox(width: context.w(8)),
                ],
              ],
            ),
            SizedBox(height: context.h(14)),
            OnboardingInfoBanner(message: AppStrings.vehicleDocsWillBeVerified),
            SizedBox(height: context.h(24)),
            UnifiedButton(
              label: AppStrings.continueAction,
              enabled: _hasFront && _hasBack,
              onPressed: _upload,
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploading(BuildContext context) {
    return OnboardingStepScaffold(
      title: AppStrings.vehiclePhotos,
      onBack: () {},
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: context.h(16)),
            Text(
              AppStrings.vehiclePhotosSubtitle,
              style: AppTypography.regular.copyWith(
                fontSize: 13,
                color: context.torkk.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
