import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class ThemeState extends Equatable {
  const ThemeState({
    required this.isPink,
    this.isNeutral = false,
    required this.themeMode,
    required this.appearanceLabel,
  });

  final bool isPink;

  /// True before the driver's gender is known (splash, login, onboarding):
  /// the app uses the purple onboarding accent instead of pink / blue.
  final bool isNeutral;
  final ThemeMode themeMode;
  final String appearanceLabel;

  ThemeState copyWith({
    bool? isPink,
    bool? isNeutral,
    ThemeMode? themeMode,
    String? appearanceLabel,
  }) {
    return ThemeState(
      isPink: isPink ?? this.isPink,
      isNeutral: isNeutral ?? this.isNeutral,
      themeMode: themeMode ?? this.themeMode,
      appearanceLabel: appearanceLabel ?? this.appearanceLabel,
    );
  }

  @override
  List<Object> get props => [isPink, isNeutral, themeMode, appearanceLabel];
}
