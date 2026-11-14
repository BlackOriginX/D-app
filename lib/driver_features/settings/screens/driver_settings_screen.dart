import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/routes/app_routes.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/common/widgets/app_confirm_dialog.dart';
import 'package:rider_app/driver_features/profile/widgets/profile_widgets.dart';
import 'package:rider_app/driver_features/settings/screens/delete_account_reason_dialog.dart';
import 'package:rider_app/service/driver_api_service.dart';
import 'package:rider_app/driver_features/settings/legal/legal_documents_screen.dart';
import 'package:rider_app/driver_features/settings/screens/driver_appearance_screen.dart';
import 'package:rider_app/driver_features/settings/screens/privacy_security_screen.dart';
import 'package:rider_app/driver_features/settings/screens/settings_language_screen.dart';

import '../../../common/constants/string_constants.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/widgets/t_text.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      title: AppStrings.settings,
      onBack: onClose,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.w(20),
          context.h(12),
          context.w(20),
          context.h(20),
        ),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.r(16)),
              border: Border.all(color: context.torkk.border),
            ),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.wb_sunny_outlined,
                  label: AppStrings.appearance,
                  onTap: () => _open(context, const DriverAppearanceScreen()),
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.verified_user_outlined,
                  label: AppStrings.privacyPolicy,
                  onTap: () => _open(context, const PrivacySecurityScreen()),
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.gavel_rounded,
                  label: 'Legal & Policies',
                  onTap: () => _open(context, const LegalDocumentsScreen()),
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.language_rounded,
                  label: AppStrings.language,
                  onTap: () => _open(context, const SettingsLanguageScreen()),
                ),
                const _SettingsDivider(),
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  label: AppStrings.deleteAccount,
                  onTap: () => _deleteAccount(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final accent = profileAccent(context);
    final confirmed = await showAppConfirmDialog(
      context,
      icon: AppDialogBadge(
        icon: Icons.delete_outline_rounded,
        color: accent,
        background: accent.withValues(alpha: 0.12),
      ),
      title: AppStrings.deleteAccountTitle,
      subtitle: AppStrings.deleteAccountSubtitle,
      confirmLabel: AppStrings.delete,
      accent: accent,
    );
    if (!confirmed || !context.mounted) return;
    final reason = await showDeleteAccountReasonDialog(context);
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await DriverApiService.deleteAccount(reason: reason);
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(
          content: TText(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go(AppRoutes.login);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(14),
          vertical: context.h(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.torkk.textPrimary, size: context.w(20)),
            SizedBox(width: context.w(12)),
            Expanded(
              child: TText(
                label,
                style: AppTypography.regular.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.slate400,
              size: context.w(22),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.torkk.border);
  }
}
