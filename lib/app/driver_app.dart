import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rider_app/app/theme/theme_bloc.dart';
import 'package:rider_app/app/theme/theme_event.dart';
import 'package:rider_app/app/theme/theme_repository.dart';
import 'package:rider_app/app/theme/theme_state.dart';
import 'package:rider_app/common/routes/app_router.dart';
import 'package:rider_app/common/security/app_lock_gate.dart';
import 'package:rider_app/common/theme/theme.dart';
import 'package:rider_app/driver_features/onboarding/onboarding_session.dart';

import '../common/utils/translations.dart';
class DriverApp extends StatelessWidget {
  const DriverApp({
    super.key,
    required this.themeRepository,
  });

  final ThemeRepository themeRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = ThemeBloc(themeRepository);

        OnboardingSession.instance.publishAccent = (isPink) {
          bloc.add(AccentChanged(isPink: isPink));
        };

        return bloc;
      },
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          return ValueListenableBuilder<String>(
            valueListenable: AppTranslations.currentLanguage,
            builder: (context, language, child) {
              return MaterialApp.router(
                key: ValueKey(language),
                title: 'Torkk Driver',
                debugShowCheckedModeBanner: false,
                themeMode: state.themeMode,
                theme: AppTheme.getTheme(
                  isPink: state.isPink,
                  isNeutral: state.isNeutral,
                  isDark: false,
                ),
                darkTheme: AppTheme.getTheme(
                  isPink: state.isPink,
                  isNeutral: state.isNeutral,
                  isDark: true,
                ),
                routerConfig: AppRouter.router,
                builder: (context, child) =>
                    AppLockGate(child: _KeyboardDismisser(child: child!)),
              );
            },
          );
        },
      ),
    );
  }
}

/// App-wide: tap anywhere outside a field to close the keyboard, and on iOS
/// (number pads have no Done key) show a small "Done" bar above the keyboard.
class _KeyboardDismisser extends StatelessWidget {
  const _KeyboardDismisser({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final showDone =
        defaultTargetPlatform == TargetPlatform.iOS && keyboard > 0;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        if (showDone)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  child: const Text('Done'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
