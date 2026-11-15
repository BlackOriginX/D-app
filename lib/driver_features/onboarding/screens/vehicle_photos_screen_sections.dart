part of 'package:rider_app/driver_features/onboarding/screens/vehicle_photos_screen.dart';

extension _VehiclePhotosScreenStateSections on _VehiclePhotosScreenState {
  Widget _verified(BuildContext context) {
    return _result(
      context,
      title: AppStrings.vehiclePhotosVerified,
      subtitle: AppStrings.vehiclePhotosVerifiedSubtitle,
      failedBack: false,
      onBack: () => _go(_PhotoPage.details),
      onContinue: widget.onFinished,
    );
  }

  Widget _action(BuildContext context) {
    return _result(
      context,
      title: AppStrings.actionRequiredPhotos,
      subtitle: _error ?? AppStrings.actionRequiredPhotosHint,
      failedBack: true,
      onBack: () => _go(_PhotoPage.details),
      onContinue: () => _go(_PhotoPage.details),
    );
  }

  Widget _result(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool failedBack,
    required VoidCallback onBack,
    required VoidCallback onContinue,
  }) {
    return OnboardingStepScaffold(
      title: AppStrings.vehiclePhotos,
      onBack: onBack,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.w(24),
          context.h(12),
          context.w(24),
          context.h(16),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: context.w(28),
              backgroundColor: failedBack
                  ? context.adaptiveTint(Color(0xFFFEE2E2))
                  : context.adaptiveTint(Color(0xFFD1FAE5)),
              child: Icon(
                Icons.directions_car_outlined,
                color: failedBack ? AppColors.error : AppColors.primary,
              ),
            ),
            SizedBox(height: context.h(12)),
            TText(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bold.copyWith(fontSize: 18, height: 1.2),
            ),
            SizedBox(height: context.h(6)),
            TText(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.regular.copyWith(
                fontSize: 13,
                color: context.torkk.textSecondary,
              ),
            ),
            SizedBox(height: context.h(16)),
            Row(
              children: [
                Expanded(
                  child: _PhotoResultCard(
                    label: AppStrings.frontPhoto,
                    failed: false,
                    imagePath: _frontPath,
                    imageUrl: _frontUrl,
                  ),
                ),
                SizedBox(width: context.w(12)),
                Expanded(
                  child: _PhotoResultCard(
                    label: AppStrings.backPhoto,
                    failed: failedBack,
                    imagePath: _backPath,
                    imageUrl: _backUrl,
                    onRetake: failedBack ? () => _go(_PhotoPage.details) : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            UnifiedButton(
              label: AppStrings.continueAction,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}
