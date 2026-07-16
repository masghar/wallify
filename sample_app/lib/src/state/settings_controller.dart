import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/wallpaper_repository.dart';

/// App settings, persisted to SQLite.
class SettingsController extends ChangeNotifier {
  SettingsController(this._db);

  final AppDatabase _db;

  static const _themeKey = 'theme_mode';
  static const _sourceKey = 'photo_source';
  static const _columnsKey = 'grid_columns';

  ThemeMode _themeMode = ThemeMode.dark;
  PhotoSourceFilter _sourceFilter = PhotoSourceFilter.all;
  int _gridColumns = 2;

  ThemeMode get themeMode => _themeMode;
  PhotoSourceFilter get sourceFilter => _sourceFilter;
  int get gridColumns => _gridColumns;

  Future<void> load() async {
    final theme = await _db.getSetting(_themeKey);
    if (theme != null) {
      _themeMode = ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system;
    }
    final source = await _db.getSetting(_sourceKey);
    if (source != null) {
      _sourceFilter =
          PhotoSourceFilter.values.asNameMap()[source] ?? PhotoSourceFilter.all;
    }
    final columns = await _db.getSetting(_columnsKey);
    if (columns != null) {
      _gridColumns = int.tryParse(columns)?.clamp(2, 4) ?? 2;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _db.setSetting(_themeKey, mode.name);
  }

  Future<void> setSourceFilter(PhotoSourceFilter filter) async {
    if (filter == _sourceFilter) return;
    _sourceFilter = filter;
    notifyListeners();
    await _db.setSetting(_sourceKey, filter.name);
  }

  Future<void> setGridColumns(int columns) async {
    final clamped = columns.clamp(2, 4);
    if (clamped == _gridColumns) return;
    _gridColumns = clamped;
    notifyListeners();
    await _db.setSetting(_columnsKey, '$clamped');
  }
}
