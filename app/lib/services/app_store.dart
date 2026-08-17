import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class AppStore {
  static const _storageKey = 'ad_master_flutter_state_v1';

  Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return AppData.empty();
    }
    try {
      return AppData.decode(raw);
    } catch (_) {
      return AppData.empty();
    }
  }

  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, data.encode());
  }
}
