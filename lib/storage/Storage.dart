import 'package:appwidgetflutter/storage/CringeCastStorage.dart';
import 'package:appwidgetflutter/storage/NicknameStorage.dart';
import 'package:appwidgetflutter/storage/WaiterStorage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  late CringeCastStorage _cringeCastStorage;
  late WaiterStorage _waiterStorage;
  late NicknameStorage _nicknameStorage;

  Storage(SharedPreferences storage) {
    _cringeCastStorage = new CringeCastStorage(storage);
    _waiterStorage = new WaiterStorage(storage);
    _nicknameStorage = new NicknameStorage(storage);
  }

  CringeCastStorage get cringeCast => _cringeCastStorage;
  WaiterStorage get waiter => _waiterStorage;
  NicknameStorage get nickname => _nicknameStorage;
}