import 'package:flutter/material.dart';

import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/common/widgets/t_text.dart';
import 'package:rider_app/driver_features/profile/widgets/profile_widgets.dart';
import 'package:rider_app/driver_features/wallet/models/wallet_txn.dart';
import 'package:rider_app/driver_features/wallet/payouts/payout_item_row.dart';
import 'package:rider_app/driver_features/wallet/screens/transaction_details_screen.dart';
import 'package:rider_app/driver_features/wallet/wallet_format.dart';
import 'package:rider_app/driver_features/wallet/wallet_payout_api.dart';

/// Statement: every wallet transaction, newest first, 20 at a time, with an
/// optional date range. GET /api/driver/wallet/transactions?limit&offset&from&to
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<PayoutItem> _items = [];
  DateTimeRange? _range;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300) _loadMore();
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<PayoutItem>> _fetch(int offset) =>
      WalletPayoutApi.fetchTransactions(
        limit: _pageSize,
        offset: offset,
        from: _range == null ? null : _ymd(_range!.start),
        to: _range == null ? null : _ymd(_range!.end),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final page = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page);
        _hasMore = page.length >= _pageSize;
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

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('STATEMENT | load more failed: $e');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _load();
  }

  void _clearRange() {
    setState(() => _range = null);
    _load();
  }

  String _rangeLabel() {
    final r = _range;
    if (r == null) return 'All dates';
    return '${payoutDateTime(r.start).split(',').first} - '
        '${payoutDateTime(r.end).split(',').first}';
  }

  String _section(DateTime? d) {
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final label = payoutDateTime(d).split(',').first;
    if (day == today) return 'Today , $label';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday , $label';
    }
    return label;
  }

  void _open(PayoutItem item) {
    final txn = WalletTxn(
      kind: item.title,
      time: payoutDateTime(item.date),
      amount: '${item.credit ? '+' : '-'}${rupees(item.amount)}',
      parcel: false,
      date: item.date,
      id: item.id,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailsScreen(txn: txn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      title: 'Statement',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.w(20),
              context.h(4),
              context.w(20),
              context.h(8),
            ),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: TText(_rangeLabel()),
                  onPressed: _pickRange,
                ),
                if (_range != null) ...[
                  SizedBox(width: context.w(8)),
                  IconButton(
                    onPressed: _clearRange,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Clear',
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
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
          _range == null
              ? 'No transactions yet'
              : 'No transactions in this date range',
          style: AppTypography.regular.copyWith(
            fontSize: 13,
            color: context.torkk.textSecondary,
          ),
        ),
      );
    }
    final children = <Widget>[];
    String? current;
    var group = <PayoutItem>[];
    void flush() {
      if (current == null) return;
      children.add(_group(context, current, group));
    }

    for (final item in _items) {
      final title = _section(item.date);
      if (title != current) {
        flush();
        current = title;
        group = [];
      }
      group.add(item);
    }
    flush();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.w(20),
          context.h(4),
          context.w(20),
          context.h(20),
        ),
        children: [
          ...children,
          if (_loadingMore)
            Padding(
              padding: EdgeInsets.all(context.w(16)),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<PayoutItem> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TText(
            title,
            style: AppTypography.regular.copyWith(
              fontSize: 13,
              color: context.torkk.textSecondary,
            ),
          ),
          SizedBox(height: context.h(8)),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.r(16)),
              border: Border.all(color: context.torkk.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.torkk.border),
                  PayoutItemRow(
                    item: items[i],
                    onTap: items[i].id.isEmpty ? null : () => _open(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
