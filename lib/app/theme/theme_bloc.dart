import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rider_app/app/theme/theme_event.dart';
import 'package:rider_app/app/theme/theme_repository.dart';
import 'package:rider_app/app/theme/theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc(this._repository) : super(_repository.read()) {
    on<AccentChanged>(_onAccent);
    on<AccentNeutral>(_onNeutral);
    on<AppearanceSelected>(_onAppearance);
  }

  final ThemeRepository _repository;

  Future<void> _onAccent(AccentChanged event, Emitter<ThemeState> emit) async {
    await _repository.savePink(event.isPink);
    emit(state.copyWith(isPink: event.isPink, isNeutral: false));
  }

  Future<void> _onNeutral(AccentNeutral event, Emitter<ThemeState> emit) async {
    if (state.isNeutral) return;
    await _repository.saveNeutral();
    emit(state.copyWith(isNeutral: true));
  }

  Future<void> _onAppearance(
    AppearanceSelected event,
    Emitter<ThemeState> emit,
  ) async {
    await _repository.saveAppearance(event.label);
    emit(
      state.copyWith(
        themeMode: ThemeRepository.modeFor(event.label),
        appearanceLabel: event.label,
      ),
    );
  }
}
