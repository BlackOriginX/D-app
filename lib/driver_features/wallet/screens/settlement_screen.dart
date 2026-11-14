import 'package:flutter/material.dart';

import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/common/widgets/t_text.dart';
import 'package:rider_app/driver_features/profile/widgets/profile_widgets.dart';
import 'package:rider_app/driver_features/wallet/payouts/payout_item_row.dart';
import 'package:rider_app/driver_features/wallet/wallet_payout_api.dart';

/// Settlement: every withdrawal the driver has made and where it stands
/// (processing, completed, failed). GET /api/driver/wallet/withdrawals
class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  List<PayoutItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await WalletPayoutApi.fetchWithdrawals();
      items.sort(
        (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePage(title: 'Settlement', child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TText(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.regular.copyWith(
                  fontSize: 13,
                  color: context.torkk.textSecondary,
                ),
              ),
              TextButton(onPressed: _load, child: const TText('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: TText(
          'No withdrawals yet',
          style: AppTypography.regular.copyWith(
            fontSize: 13,
            color: context.torkk.textSecondary,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.w(20),
          context.h(8),
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
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.torkk.border),
                  _row(context, _items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PayoutItem item) {
    // Withdrawals always leave the wallet.
    final shown = PayoutItem(
      id: item.id,
      title: item.title,
      status: item.status,
      amount: item.amount,
      credit: false,
      date: item.date,
      reference: item.reference,
      note: item.note,
    );
    return Column(
      children: [
        PayoutItemRow(item: shown, showStatus: true),
        if (item.note.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.w(66),
              0,
              context.w(14),
              context.h(12),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TText(
                item.note,
                style: AppTypography.regular.copyWith(
                  fontSize: 12,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
