import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/constants/string_constants.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/driver_features/onboarding/widgets/kyc_form_widgets.dart';
import 'package:rider_app/common/widgets/app_text_field.dart';
import 'package:rider_app/common/widgets/onboarding_step_scaffold.dart';
import 'package:rider_app/common/widgets/unified_button.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/driver_features/onboarding/kyc_documents_api.dart';

/// Insurance step. The insurance PDF and its expiry date are sent to the
/// server. Skip (or Continue with no PDF chosen) moves on without uploading.
class VehicleInsuranceScreen extends StatefulWidget {
  const VehicleInsuranceScreen({
    super.key,
    required this.onBack,
    required this.onHelp,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onSkip;

  @override
  State<VehicleInsuranceScreen> createState() => _VehicleInsuranceScreenState();
}

class _VehicleInsuranceScreenState extends State<VehicleInsuranceScreen> {
  final _insuranceExpiry = TextEditingController();
  final _permitExpiry = TextEditingController();
  bool _commercialPermit = false;
  String? _pdfPath;
  String _pdfName = '';
  DateTime? _insuranceDate;
  bool _uploaded = false;
  bool _uploading = false;

  @override
  void dispose() {
    _insuranceExpiry.dispose();
    _permitExpiry.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<void> _pickDate(
    TextEditingController controller, {
    bool insurance = false,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: insurance ? now : DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (insurance) {
        _insuranceDate = picked;
        _uploaded = false;
      }
      controller.text =
          '${picked.day} ${_months[picked.month - 1]} ${picked.year}';
    });
  }

  Future<void> _pickPdf() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final path = file?.path;
      if (path == null || !mounted) return;
      setState(() {
        _pdfPath = path;
        _pdfName = file!.name;
        _uploaded = false;
      });
    } catch (e) {
      debugPrint('[KYC INSURANCE PICK] failed: $e');
      _snack('Could not open the file picker.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Continue: uploads the insurance PDF with its expiry date (YYYY-MM-DD),
  /// then moves on. With no PDF chosen it just moves on, like Skip.
  Future<void> _continue() async {
    final path = _pdfPath;
    if (path == null || _uploaded) {
      widget.onSkip();
      return;
    }
    final date = _insuranceDate;
    if (date == null) {
      _snack('Select the insurance expiry date.');
      return;
    }
    final expiry =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    setState(() => _uploading = true);
    try {
      await KycDocumentsApi.uploadInsurance(pdfPath: path, expiryDate: expiry);
      if (!mounted) return;
      setState(() {
        _uploaded = true;
        _uploading = false;
      });
      widget.onSkip();
    } on KycApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: AppStrings.vehicleInsurance,
      onBack: widget.onBack,
      onHelp: widget.onHelp,
      headerAction: TextButton(
        onPressed: widget.onSkip,
        child: Text(
          AppStrings.skip,
          style: AppTypography.bold.copyWith(
            fontSize: 15,
            color: context.legible(AppColors.primary),
          ),
        ),
      ),
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
            KycUploadTile(
              label: AppStrings.uploadInsurance,
              uploaded: _pdfPath != null,
              onTap: _pickPdf,
            ),
            SizedBox(height: context.h(16)),
            Text(
              '${AppStrings.expiryDate} *',
              style: AppTypography.regular.copyWith(fontSize: 13),
            ),
            SizedBox(height: context.h(8)),
            _dateField(_insuranceExpiry, insurance: true),
            SizedBox(height: context.h(16)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.permitIfApplicable,
                    style: AppTypography.regular.copyWith(fontSize: 13),
                  ),
                ),
                Text(
                  AppStrings.commercialPermit,
                  style: AppTypography.regular.copyWith(fontSize: 12),
                ),
                SizedBox(width: context.w(8)),
                Switch(
                  value: _commercialPermit,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) =>
                      setState(() => _commercialPermit = value),
                ),
              ],
            ),
            SizedBox(height: context.h(8)),
            KycUploadTile(
              label: AppStrings.uploadPermit,
              uploaded: false,
              onTap: () {},
            ),
            SizedBox(height: context.h(16)),
            Text(
              '${AppStrings.expiryDate} *',
              style: AppTypography.regular.copyWith(fontSize: 13),
            ),
            SizedBox(height: context.h(8)),
            _dateField(_permitExpiry),
            SizedBox(height: context.h(16)),
            Text(
              AppStrings.preview,
              style: AppTypography.bold.copyWith(fontSize: 14, height: 1.2),
            ),
            SizedBox(height: context.h(10)),
            _pdfCard(),
            SizedBox(height: context.h(16)),
            KycPendingBanner(title: AppStrings.verificationPending),
            SizedBox(height: context.h(24)),
            UnifiedButton(
              label: AppStrings.continueAction,
              enabled: !_uploading,
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfCard() {
    final chosen = _pdfPath != null;
    return GestureDetector(
      onTap: _pickPdf,
      child: Container(
        padding: EdgeInsets.all(context.w(12)),
        decoration: BoxDecoration(
          color: context.torkk.surfaceMuted,
          borderRadius: BorderRadius.circular(context.r(16)),
          border: Border.all(color: context.torkk.border),
        ),
        child: Row(
          children: [
            Icon(
              chosen ? Icons.picture_as_pdf : Icons.badge_outlined,
              color: chosen ? AppColors.error : AppColors.slate300,
              size: context.w(32),
            ),
            SizedBox(width: context.w(10)),
            Expanded(
              child: Text(
                chosen ? _pdfName : AppStrings.tapToUpload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.regular.copyWith(fontSize: 13),
              ),
            ),
            if (_uploading)
              SizedBox(
                width: context.w(18),
                height: context.w(18),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else if (chosen)
              Icon(
                Icons.refresh,
                size: context.w(16),
                color: context.legible(AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(
    TextEditingController controller, {
    bool insurance = false,
  }) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        AppTextField(controller: controller, hintText: AppStrings.expiryDate),
        IconButton(
          onPressed: () => _pickDate(controller, insurance: insurance),
          icon: Icon(
            Icons.calendar_today_outlined,
            size: context.w(18),
            color: context.torkk.textSecondary,
          ),
        ),
      ],
    );
  }
}
