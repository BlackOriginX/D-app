import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/common/constants/asset_constants.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/common/widgets/t_text.dart';
import 'package:rider_app/driver_features/profile/widgets/profile_widgets.dart';
import 'package:rider_app/driver_features/subscription/models/subscription_plan.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '500',
  );
  PayMethod _selectedMethod = PayMethod.upi;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _addMoney() {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount to continue.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet top-up payments are not available yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      title: 'Add Money to Wallet',
      showAiChat: false,
      bottom: Padding(
        padding: EdgeInsets.fromLTRB(
          context.w(32),
          context.h(8),
          context.w(16),
          context.h(20),
        ),
        child: SizedBox(
          width: double.infinity,
          height: context.h(54),
          child: FilledButton(
            onPressed: _addMoney,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1642C8),
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.r(14)),
              ),
            ),
            child: TText(
              'Add Money',
              style: AppTypography.bold.copyWith(
                color: Colors.white,
                fontSize: 18,
                height: 1,
              ),
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.w(28),
                context.h(26),
                context.w(20),
                context.h(8),
              ),
              children: [
                TText(
                  'Enter Amount',
                  style: AppTypography.regular.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                SizedBox(height: context.h(8)),
                SizedBox(
                  height: context.h(54),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppTypography.bold.copyWith(
                      fontSize: 16,
                      color: context.torkk.textPrimary,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: AppTypography.bold.copyWith(
                        fontSize: 16,
                        color: context.torkk.textPrimary,
                      ),
                      filled: true,
                      fillColor: context.torkk.surface,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.w(16),
                        vertical: context.h(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.r(14)),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.r(14)),
                        borderSide: const BorderSide(color: Color(0xFF1642C8)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: context.h(16)),
                TText(
                  'Payment Methods',
                  style: AppTypography.regular.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                SizedBox(height: context.h(8)),
                _PaymentMethodTile(
                  title: 'UPI',
                  subtitle: 'Select using any UPI app',
                  selected: _selectedMethod == PayMethod.upi,
                  onTap: () => setState(() => _selectedMethod = PayMethod.upi),
                  child: Image.asset(
                    AppAssets.upi,
                    width: context.w(32),
                    height: context.w(32),
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: context.h(4)),
                _PaymentMethodTile(
                  title: 'Debit/Credit Card',
                  subtitle: 'Visa, Master Card, Rupay',
                  selected: _selectedMethod == PayMethod.card,
                  onTap: () => setState(() => _selectedMethod = PayMethod.card),
                  child: Icon(
                    Icons.credit_card_outlined,
                    size: context.w(22),
                    color: const Color(0xFFF08A00),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.w(20),
              0,
              context.w(20),
              context.h(8),
            ),
            child: const _WalletPromo(),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: context.h(72),
          padding: EdgeInsets.symmetric(horizontal: context.w(14)),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1642C8).withValues(alpha: 0.1)
                : context.torkk.surface,
            borderRadius: BorderRadius.circular(context.r(14)),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1642C8)
                  : const Color(0xFFE8EDF5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: context.w(48),
                height: context.w(48),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF7F2FF)
                      : const Color(0xFFFFF9E9),
                  borderRadius: BorderRadius.circular(context.r(14)),
                ),
                alignment: Alignment.center,
                child: child,
              ),
              SizedBox(width: context.w(14)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TText(
                      title,
                      style: AppTypography.regular.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TText(
                      subtitle,
                      style: AppTypography.regular.copyWith(
                        fontSize: 12,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPromo extends StatelessWidget {
  const _WalletPromo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.h(112),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: context.h(58),
            margin: EdgeInsets.symmetric(horizontal: context.w(14)),
            padding: EdgeInsets.only(left: context.w(70), right: context.w(70)),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FF),
              border: Border.all(color: const Color(0xFFDCEBFF)),
              borderRadius: BorderRadius.circular(context.r(12)),
            ),
            alignment: Alignment.center,
            child: TText(
              'Add money & enjoy seamless rides and deliveries!',
              textAlign: TextAlign.center,
              style: AppTypography.bold.copyWith(
                fontSize: 10,
                height: 1.3,
                color: const Color(0xFF18243A),
              ),
            ),
          ),
          Positioned(
            left: context.w(8),
            child: Container(
              width: context.w(62),
              height: context.w(62),
              decoration: BoxDecoration(
                color: const Color(0xFFE8DFFF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: const Color(0xFF5B2BC4),
                size: context.w(30),
              ),
            ),
          ),
          Positioned(
            right: context.w(8),
            child: Container(
              width: context.w(58),
              height: context.w(58),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2CB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                Icons.directions_bike_rounded,
                color: const Color(0xFF1642C8),
                size: context.w(30),
              ),
            ),
          ),
          Positioned(
            bottom: context.h(13),
            child: TText(
              'Keep your wallet ready for faster payments',
              style: AppTypography.regular.copyWith(
                fontSize: 8,
                color: const Color(0xFF718096),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
