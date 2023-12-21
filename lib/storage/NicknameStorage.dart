import 'package:shared_preferences/shared_preferences.dart';

class NicknameStorage {
  late SharedPreferences storage;
  NicknameStorage(SharedPreferences storage) {
    this.storage = storage;
  }

  Future<bool> set(String value) async {
    return await storage.setString(getKey(), value);
  }

  Future<String?> get() async {
    return storage.getString(getKey());
  }

  String getKey () {
    return "nickname";
  }
}