import 'package:appwidgetflutter/storage/AbstractActivatedStorage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaiterStorage extends AbstractActivatedStorage {
  WaiterStorage(SharedPreferences storage) : super(storage);

  @override
  String getKey() {
    return "waiter";
  }

}