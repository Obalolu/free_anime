import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit({required Box box}) : _box = box, super(ThemeMode.dark);

  final Box _box;
  static const _key = 'theme_mode';

  Future<void> load() async {
    final value = _box.get(_key) as String?;
    if (value == 'dark') {
      emit(ThemeMode.dark);
      return;
    }
    emit(ThemeMode.dark);
  }

  Future<void> enforceDarkMode() async {
    await _box.put(_key, 'dark');
    emit(ThemeMode.dark);
  }
}
