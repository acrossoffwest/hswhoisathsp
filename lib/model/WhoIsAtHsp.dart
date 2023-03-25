class WhoIsAtHsp {
  final int headcount;
  final int unknown_devices;
  final List<String> users;

  WhoIsAtHsp({
    required this.headcount,
    required this.unknown_devices,
    required this.users
  });

  int getUsersLength() {
    return users.length;
  }

  String getUsersListAsString() {
    return users.asMap().map((key, value) => MapEntry(key, "${key + 1}. $value")).values.join("\n");
  }

  factory WhoIsAtHsp.fromJson(Map<String, dynamic> json) {
    var rawUsers = json['users'] as List;
    List<String> users = rawUsers.map<String>((e) => e).toList();
    return WhoIsAtHsp(headcount: json['headcount'], unknown_devices: json['unknown_devices'], users: users);
  }
}