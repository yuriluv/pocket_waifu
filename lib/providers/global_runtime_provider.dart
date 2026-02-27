import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/global_runtime_registry.dart';

class GlobalRuntimeProvider extends ChangeNotifier {
  static const String _prefsKey = 'global_runtime_enabled';

  bool _isEnabled = true;
  bool _isLoading = false;

  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;

  GlobalRuntimeProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefsKey) ?? true;
    } catch (e) {
      debugPrint('GlobalRuntimeProvider load failed: $e');
      _isEnabled = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
    } catch (e) {
      debugPrint('GlobalRuntimeProvider save failed: $e');
    }

    if (enabled) {
      GlobalRuntimeRegistry.instance.notifyEnabled();
    } else {
      GlobalRuntimeRegistry.instance.notifyDisabled();
    }
  }
}
