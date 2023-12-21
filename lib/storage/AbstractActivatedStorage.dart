import 'package:shared_preferences/shared_preferences.dart';

abstract class AbstractActivatedStorage {
  late SharedPreferences storage;
  AbstractActivatedStorage(SharedPreferences storage) {
    this.storage = storage;
  }

  String getKey();

  Future<bool> setIsActivated(bool value) async {
    if (!value) {
      return await storage.remove(getIsActivateKey());
    }
    return await storage.setBool(getIsActivateKey(), value);
  }

  Future<bool> isActivated() async {
    return (storage.getBool(getIsActivateKey()) == null) ? false : true;
  }

  String getIsActivateKey () {
    return "is" + getKey().toLowerCase() + "activated";
  }
}