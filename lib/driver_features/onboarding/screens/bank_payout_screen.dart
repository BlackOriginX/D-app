import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rider_app/common/constants/app_colors.dart';
import 'package:rider_app/common/constants/asset_constants.dart';
import 'package:rider_app/common/constants/string_constants.dart';
import 'package:rider_app/common/theme/app_typography.dart';
import 'package:rider_app/common/utils/screen_utils.dart';
import 'package:rider_app/driver_features/onboarding/widgets/kyc_form_widgets.dart';
import 'package:rider_app/common/widgets/app_text_field.dart';
import 'package:rider_app/common/widgets/onboarding_info_banner.dart';
import 'package:rider_app/common/widgets/onboarding_step_scaffold.dart';
import 'package:rider_app/common/widgets/unified_button.dart';
import 'package:rider_app/driver_features/onboarding/kyc_documents_api.dart';
import 'package:rider_app/service/driver_api_service.dart';
import 'package:rider_app/common/theme/torkk_colors.dart';

part 'bank_payout_screen_parts/bank_step.dart';
part 'bank_payout_screen_parts/reason.dart';
part 'bank_payout_screen_sections.dart';

enum _BankPage { form, verifying, verified, failed }

class BankPayoutScreen extends StatefulWidget {
  const BankPayoutScreen({
    super.key,
    required this.onBack,
    required this.onHelp,
    required this.onFinished,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;
  final ValueChanged<BankPayoutDetails> onFinished;

  @override
  State<BankPayoutScreen> createState() => _BankPayoutScreenState();
}

class _BankPayoutScreenState extends State<BankPayoutScreen> {
  _BankPage _page = _BankPage.form;
  int _bankDone = 0;
  String _submittedAt = '';
  String _branch = '';
  String? _error;
  bool _findingIfsc = false;

  /// Rebuilds so the error messages follow what is typed.
  void _refresh() => setState(() {});

  ({int min, int max}) get _limits => accountNumberLimits(_ifsc.text);

  /// Shown under the account number field while it is the wrong length.
  String? get _accountError {
    final length = _account.text.trim().length;
    if (length == 0) return null;
    // Only the longest allowed length is enforced while typing; too short is
    // flagged below 9 digits (no Indian bank uses fewer).
    if (length < 9) return 'Account number must be at least 9 digits';
    return null;
  }

  /// Shown under the confirm field when the two numbers differ.
  String? get _confirmError {
    if (_confirm.text.isEmpty) return null;
    return _confirm.text == _account.text
        ? null
        : 'Account numbers do not match';
  }

  Timer? _bankTimer;
  final _name = TextEditingController();
  final _account = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _bank = TextEditingController();

  @override
  void dispose() {
    _bankTimer?.cancel();
    _name.dispose();
    _account.dispose();
    _confirm.dispose();
    _ifsc.dispose();
    _bank.dispose();
    super.dispose();
  }

  void _go(_BankPage page) => setState(() => _page = page);

  String _submittedStamp() {
    final now = DateTime.now();
    const months = [
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
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '${now.day} ${months[now.month - 1]} ${now.year}, $hour:$minute $period';
  }

  /// "Find IFSC": looks the code up and fills the bank name and branch.
  /// "Find IFSC": sends the account holder name and account number (and the
  /// IFSC if typed) and fills the IFSC, bank name and branch from the reply.
  Future<void> _findIfsc() async {
    final holder = _name.text.trim();
    final account = _account.text.trim();
    final typedIfsc = _ifsc.text.trim().toUpperCase();
    final ready = holder.isNotEmpty && account.isNotEmpty;
    debugPrint(
      'ONB_API | FIND IFSC | BUTTON PRESSED | holder="$holder" account="$account" '
      'ifsc="$typedIfsc" -> ${ready ? 'calling API' : 'API NOT called (holder name or account number is empty)'}',
    );
    if (!ready) {
      _snack('Enter the account holder name and account number first');
      return;
    }
    setState(() => _findingIfsc = true);
    try {
      final found = await KycDocumentsApi.findIfsc(
        ifsc: typedIfsc,
        accountHolderName: holder,
        accountNumber: account,
      );
      if (!mounted) return;
      setState(() {
        if (found.ifsc.isNotEmpty) _ifsc.text = found.ifsc.toUpperCase();
        if (found.bankName.isNotEmpty) _bank.text = found.bankName;
        _branch = found.branchName;
      });
    } on KycApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _findingIfsc = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// "Save & Verify": checks the form, then POSTs the bank details.
  Future<void> _submit() async {
    final error = _validate();
    debugPrint(
      'ONB_API | BANK DETAILS SAVE | SAVE & VERIFY PRESSED | '
      'holder="${_name.text.trim()}" account="${_account.text.trim()}" '
      'ifsc="${_ifsc.text.trim()}" bank="${_bank.text.trim()}" branch="$_branch" -> '
      '${error == null ? 'calling API' : 'API NOT called: $error'}',
    );
    if (error != null) {
      setState(() {
        _error = error;
        _page = _BankPage.failed;
      });
      return;
    }
    _bankTimer?.cancel();
    setState(() {
      _error = null;
      _submittedAt = _submittedStamp();
      _bankDone = 1;
      _page = _BankPage.verifying;
    });
    // Moves the progress rows along while the server call runs (stops at 2).
    _bankTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted || _bankDone >= 2) {
        timer.cancel();
        return;
      }
      setState(() => _bankDone += 1);
    });
    try {
      final ifsc = _ifsc.text.trim().toUpperCase();
      await DriverApiService.saveBankDetails(
        accountHolderName: _name.text.trim(),
        accountNumber: _account.text.trim(),
        ifscCode: ifsc,
        bankName: _bank.text.trim(),
        branchName: _branch.isEmpty ? _bank.text.trim() : _branch,
      );
      if (!mounted) return;
      _bankTimer?.cancel();
      setState(() => _bankDone = 3);
    } catch (e) {
      if (!mounted) return;
      debugPrint('ONB_API | BANK DETAILS SAVE | ERROR | $e');
      _bankTimer?.cancel();
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _page = _BankPage.failed;
      });
    }
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter the account holder name.';
    if (_account.text.trim().isEmpty) return 'Enter the account number.';
    final accountError = _accountError;
    if (accountError != null) return '$accountError.';
    if (_account.text.trim() != _confirm.text.trim()) {
      return 'Account numbers do not match.';
    }
    if (_ifsc.text.trim().length != 11) {
      return 'Enter a valid 11 character IFSC code.';
    }
    if (_bank.text.trim().isEmpty) return 'Enter the bank name.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _BankPage.form => _form(context),
      _BankPage.verifying => _verifying(context),
      _BankPage.verified => _verified(context),
      _BankPage.failed => _failed(context),
    };
  }
}

/// Account number length limits (min, max) for the bank in [ifsc]. The first 4
/// letters of an IFSC are the bank code. Banks not listed use 9 to 18 digits,
/// which covers every bank in India.
({int min, int max}) accountNumberLimits(String ifsc) {
  const byBank = <String, ({int min, int max})>{
    'HDFC': (min: 12, max: 14),
    'ICIC': (min: 12, max: 12),
    'SBIN': (min: 9, max: 17),
    'UTIB': (min: 15, max: 15),
    'KKBK': (min: 10, max: 14),
    'PUNB': (min: 14, max: 16),
    'BARB': (min: 14, max: 14),
    'CNRB': (min: 13, max: 13),
    'UBIN': (min: 15, max: 15),
    'YESB': (min: 9, max: 15),
    'IDIB': (min: 9, max: 15),
  };
  final code = ifsc.trim().toUpperCase();
  if (code.length >= 4) {
    final hit = byBank[code.substring(0, 4)];
    if (hit != null) return hit;
  }
  return (min: 9, max: 18);
}

class BankPayoutDetails {
  const BankPayoutDetails({
    required this.holderName,
    required this.accountNumber,
    required this.ifsc,
    required this.bankName,
  });

  final String holderName;
  final String accountNumber;
  final String ifsc;
  final String bankName;
}
