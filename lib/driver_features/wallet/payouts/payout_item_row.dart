import 'package:flutter/material.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/common/widgets/t_text.dart';
import 'package:rider_app/driver_features/wallet/wallet_format.dart';
import 'package:rider_app/driver_features/wallet/wallet_payout_api.dart';

const _months = [
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

/// "14 Nov, 10:24 pm" (empty when there is no date).
String payoutDateTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]}, $h:$m ${d.hour >= 12 ? 'pm' : 'am'}';
}

/// Colour and label for a payout / withdrawal status string.
(Color, String) payoutStatusStyle(String status) {
  final s = status.toLowerCase();
  if (s.isEmpty) return (AppColors.slate400, '');
  if (s.contains('fail') || s.contains('reject') || s.contains('revers')) {
    return (const Color(0xFFDC2626), _title(status));
  }
  if (s.contains('pend') ||
      s.contains('process') ||
      s.contains('queue') ||
      s.contains('initiat')) {
    return (const Color(0xFFF59E0B), _title(status));
  }
  return (const Color(0xFF16A34A), _title(status));
}

String _title(String v) {
  final t = v.replaceAll('_', ' ').trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1).toLowerCase();
}

/// One line of the payout history: icon, title, date, amount and (optionally)
/// the status. Used by Payouts, Statement and Settlement.
class PayoutItemRow extends StatelessWidget {
  const PayoutItemRow({
    super.key,
    required this.item,
    this.onTap,
    this.showStatus = false,
  });

  final PayoutItem item;
  final VoidCallback? onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusText) = payoutStatusStyle(item.status);
    final amountColor = item.credit
        ? const Color(0xFF16A34A)
        : context.torkk.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(14),
          vertical: context.h(14),
        ),
        child: Row(
          children: [
            Container(
              width: context.w(40),
              height: context.w(40),
              decoration: BoxDecoration(
                color: context.torkk.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.credit
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: item.credit
                    ? const Color(0xFF16A34A)
                    : AppColors.slate400,
                size: context.w(20),
              ),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TText(
                    item.title,
                    style: AppTypography.bold.copyWith(fontSize: 14),
                  ),
                  TText(
                    [
                      payoutDateTime(item.date),
                      if (item.reference.isNotEmpty) 'Ref ${item.reference}',
                    ].where((e) => e.isNotEmpty).join('  •  '),
                    style: AppTypography.regular.copyWith(
                      fontSize: 12,
                      color: context.torkk.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TText(
                  '${item.credit ? '+' : '-'} ${rupees(item.amount)}',
                  style: AppTypography.bold.copyWith(
                    fontSize: 14,
                    color: amountColor,
                  ),
                ),
                if (showStatus && statusText.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: context.h(4)),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(8),
                      vertical: context.h(2),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(context.r(20)),
                    ),
                    child: TText(
                      statusText,
                      style: AppTypography.bold.copyWith(
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
