import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/brand_config_repository.dart';

class BrandThemeProvider extends ChangeNotifier {
  BrandThemeProvider({BrandConfigRepository? repository})
      : _repository = repository ?? BrandConfigRepository();

  final BrandConfigRepository _repository;

  BrandConfig? _config;
  bool _loading = true;
  String? _error;

  BrandConfig? get config => _config;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load(String brandKey) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _config = await _repository.getBrand(brandKey);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> save(BrandConfig config) async {
    await _repository.saveBrand(config);
    _config = config;
    notifyListeners();
  }

  ThemeData get theme => HalalFoodTheme.fromBrand(_config);
}
