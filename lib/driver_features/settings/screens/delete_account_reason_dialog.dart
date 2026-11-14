import 'package:flutter/material.dart';

import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/widgets/t_text.dart';

/// Asks why the driver is leaving and tells them the remaining wallet balance
/// is given up. Returns the reason, or null when they back out.
Future<String?> showDeleteAccountReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DeleteAccountReasonDialog(),
  );
}

class _DeleteAccountReasonDialog extends StatefulWidget {
  const _DeleteAccountReasonDialog();

  @override
  State<_DeleteAccountReasonDialog> createState() =>
      _DeleteAccountReasonDialogState();
}

class _DeleteAccountReasonDialogState
    extends State<_DeleteAccountReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: const TText('Why are you leaving?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reason,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Reason for deleting your account',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TText(
            'Any money left in your wallet will be given up when the account is deleted.',
            style: AppTypography.regular.copyWith(
              fontSize: 12,
              color: context.torkk.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TText('Cancel'),
        ),
        TextButton(
          onPressed: canDelete
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: const TText('Delete'),
        ),
      ],
    );
  }
}
