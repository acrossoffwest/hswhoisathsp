import 'package:appwidgetflutter/storage/AbstractActivatedStorage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CringeCastStorage extends AbstractActivatedStorage {
  CringeCastStorage(SharedPreferences storage) : super(storage);

  @override
  String getKey() {
    return "cringecast";
  }

}