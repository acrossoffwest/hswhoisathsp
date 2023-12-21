import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:ui';

import 'package:appwidgetflutter/exception/FailedFetchCarbonLifeException.dart';
import 'package:appwidgetflutter/storage/Storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:appwidgetflutter/model/WhoIsAtHsp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lib/local_notice_service.dart';
import 'package:notification_permissions/notification_permissions.dart';

final observedUsersController = TextEditingController(text: "somebody");
final nicknameController = TextEditingController(text: "");
final service = FlutterBackgroundService();

late SharedPreferences sharedPreferences;
late Storage storage;

onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  const reloadMinutes = Duration(minutes: 5);
  Timer.periodic(reloadMinutes, (Timer t) async {
    final users = await updateUsers();
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Waiting for: ${await getObservedUsersPref()}",
        content: "Update ${DateTime.now()}",
      );
    }
    if (checkObservedUserInNewResponse(await getObservedUsersPref(), users)) {
      log("stop timer");
      t.cancel();
      service.stopSelf();
    }
    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
      },
    );
  });
}

initializeBackgroundService() async {
  if (!await storage.waiter.isActivated()) {
    log("Waiter deactivated");
    return;
  }
  if (await getObservedUsersPref() == "") {
    log("There is not observing users");
    return;
  }
  if (await service.isRunning()) {
    service.invoke("stopService");
  }
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  service.startService();
}

Future<SharedPreferences> prefs() async {
  return await SharedPreferences.getInstance();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sharedPreferences = await prefs();

  storage = new Storage(sharedPreferences);

  await LocalNoticeService().setup();
  await initializeBackgroundService();
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  runApp(MyApp());
}

Future<bool> saveObservedUsersPref(String observedUsers) async {
  return await sharedPreferences.setString("observedUsers", observedUsers);
}

Future<String> getObservedUsersPref() async {
  var res = sharedPreferences.getString("observedUsers");
  return res == null ? "" : res;
}

Future<http.Response> loadCarbonLife() {
  return http.get(Uri.parse('https://whois.at.hsp.sh/api/now')).timeout(
    const Duration(seconds: 3), onTimeout: () {
      log("Request successful");
      return http.Response("Request timeout", 504);
    }
  );
}

Future<WhoIsAtHsp> fetchCarbonLife() async {
  final response = await loadCarbonLife();
  if (response.statusCode == 200) {
    log("Request successful");
    var body = jsonDecode(response.body);
    return WhoIsAtHsp.fromJson(body);
  }
  log("Request failed");
  throw FailedFetchCarbonLifeException();
}

void observedUserOnline(String user) {
  log("observedUserOnline");
  LocalNoticeService().notify(
    "Online Notifier",
    "User(s): \"${user}\" is online",
    "observedUser",
  );
}

bool checkObservedUserInNewResponse(
    String observedUsersString, List<String> users) {
  List<String> observedUsers =
      observedUsersString.split(",").map((e) => e.trim()).toList();
  List<String> onlineUsers = [];
  List<String> usersWithLowerCase = users.map((e) => e.toLowerCase()).toList();
  log(observedUsersString);
  observedUsers.forEach((user) {
    if (usersWithLowerCase.contains(user.toLowerCase())) {
      onlineUsers.add(user);
    }
  });
  if (onlineUsers.isNotEmpty) {
    observedUserOnline(onlineUsers.join(", "));
    return true;
  }
  return false;
}

// Called when Doing Background Work initiated from Widget
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'updatecounter') {
    final users = await updateUsers();
    checkObservedUserInNewResponse(await getObservedUsersPref(), users);
  }
}

Future<List<String>> updateUsers() async {
  await HomeWidget.saveWidgetData<bool>('_isLoading', true);
  await HomeWidget.updateWidget(
      name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
  try {
    final whoIsAtHsp = await fetchCarbonLife();
    await HomeWidget.saveWidgetData<int>(
        '_counter', whoIsAtHsp.getUsersLength());
    await HomeWidget.saveWidgetData<String>(
        '_carbonLife', whoIsAtHsp.getUsersListAsString());
    await HomeWidget.saveWidgetData<bool>('_isLoading', false);
    await HomeWidget.updateWidget(
        name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
    return whoIsAtHsp.users;
  } on FailedFetchCarbonLifeException {
    return [];
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HS: Who is at HSP',
      theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          backgroundColor: Colors.black),
      home: MyHomePage(
        title: 'HS: Who is at HSP',
        key: new Key("home-widget"),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({required Key key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _counter = 0;
  String _carbonLife = "";
  bool _isLoading = false;
  bool _isWaiterActivated = false;
  bool _isCringeCastActivated = false;
  late Timer reloadTimer;

  late Future<String> permissionStatusFuture;

  var permGranted = "granted";
  var permDenied = "denied";
  var permUnknown = "unknown";
  var permProvisional = "provisional";

  @override
  void initState() {
    getObservedUsersPref().then((value) =>
        observedUsersController.value = TextEditingValue(text: value));

    storage.waiter.isActivated().then((value) => _isWaiterActivated = value!);
    storage.cringeCast.isActivated().then((value) => _isCringeCastActivated = value!);
    storage.nickname.get().then((value) => nicknameController.value = TextEditingValue(text: value!));

    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => loadData());
    loadData(); // This will load data from widget every time app is opened
    permissionStatusFuture = getCheckNotificationPermStatus();
    // With this, we will be able to check if the permission is granted or not
    // when returning to the application
    WidgetsBinding.instance.addObserver(this);
    permissionStatusFuture.then((value) => {
          if (permGranted != value)
            {
              NotificationPermissions.requestNotificationPermissions(
                  iosSettings: const NotificationSettingsIos(
                      sound: true, badge: true, alert: true))
            }
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        permissionStatusFuture = getCheckNotificationPermStatus();
        permissionStatusFuture.then((value) => {
              if (permGranted != value)
                {
                  NotificationPermissions.requestNotificationPermissions(
                      iosSettings: const NotificationSettingsIos(
                          sound: true, badge: true, alert: true))
                }
            });
      });
    }
  }

  /// Checks the notification permission status
  Future<String> getCheckNotificationPermStatus() {
    return NotificationPermissions.getNotificationPermissionStatus()
        .then((status) {
      switch (status) {
        case PermissionStatus.denied:
          return permDenied;
        case PermissionStatus.granted:
          return permGranted;
        case PermissionStatus.unknown:
          return permUnknown;
        case PermissionStatus.provisional:
          return permProvisional;
        default:
          return "";
      }
    });
  }

  void loadData() async {
    _counter =
        (await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0))!;
    _carbonLife = (await HomeWidget.getWidgetData<String>('_carbonLife',
        defaultValue: ""))!;
    _isLoading = (await HomeWidget.getWidgetData<bool>('_isLoading',
        defaultValue: false))!;
    setState(() {});
  }

  Future<void> updateAppWidget() async {
    await HomeWidget.saveWidgetData<bool>('_isLoading', _isLoading);
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.saveWidgetData<String>('_carbonLife', _carbonLife);
    await HomeWidget.updateWidget(
        name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
  }

  Future<void> _refreshData() async {
    initializeBackgroundService();
    setState(() => {_isLoading = true});
    final WhoIsAtHsp whoIsAtHsp = await fetchCarbonLife();

    checkObservedUserInNewResponse(
        await getObservedUsersPref(), whoIsAtHsp.users);

    setState(() => {
          _counter = whoIsAtHsp.getUsersLength(),
          _carbonLife = whoIsAtHsp.getUsersListAsString(),
          _isLoading = false,
        });
    updateAppWidget();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        backgroundColor: Color(0x11111100),
      ),
      body: Container(
        margin: const EdgeInsets.all(20.0),
        child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Invoke "debug painting" (press "p" in the console, choose the
            // "Toggle Debug Paint" action from the Flutter Inspector in Android
            // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
            // to see the wireframe for each widget.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            mainAxisAlignment: MainAxisAlignment.start,
            children: !_isLoading
                ? <Widget>[
                    Row(
                      children: [
                        Text(
                            'There are $_counter carbon-based lifeforms in HS according to our measurements.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.start),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$_carbonLife',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Updated at: ${DateTime.now().toLocal()}',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text("Activate CRINGECAST.NET"),
                            value: _isCringeCastActivated,
                            onChanged: (newValue) async {
                              storage.cringeCast.setIsActivated(newValue!);
                              setState(() {
                                _isCringeCastActivated = newValue;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,  //  <-- leading Checkbox
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text("Wait for somebody or set specific person's nickname"),
                            value: _isWaiterActivated,
                            onChanged: (newValue) async {
                              storage.waiter.setIsActivated(newValue!);
                              setState(() {
                                _isWaiterActivated = newValue;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,  //  <-- leading Checkbox
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: observedUsersController,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText:
                                  'Who are you waiting for? (Type users name by comma separated)',
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            onChanged: (text) async {
                              await saveObservedUsersPref(text);
                            },
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ].where((element) => _isWaiterActivated).toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nicknameController,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText:
                              'Your nickname',
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                            onChanged: (text) async {
                              await storage.nickname.set(text);
                            },
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                  ]
                : <Widget>[
                    Row(
                      children: [
                        Text('Loading...',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.start),
                      ],
                    ),
                  ],
          ),
        ),
      ),
      floatingActionButton: OutlinedButton(
        child: Text(
          'Save & Refresh',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white),
        ),
        onPressed: _refreshData,
      ), // This trailing comma makes auto-formatting nicer for build methods.
      backgroundColor: Color(0x1c1c1c00),
    );
  }
}

class _MyAppState extends State<MyHomePage> with WidgetsBindingObserver {
  late Future<String> permissionStatusFuture;

  var permGranted = "granted";
  var permDenied = "denied";
  var permUnknown = "unknown";
  var permProvisional = "provisional";

  @override
  void initState() {
    super.initState();
    // set up the notification permissions class
    // set up the future to fetch the notification data
    permissionStatusFuture = getCheckNotificationPermStatus();
    // With this, we will be able to check if the permission is granted or not
    // when returning to the application
    WidgetsBinding.instance.addObserver(this);
  }

  /// When the application has a resumed status, check for the permission
  /// status
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        permissionStatusFuture = getCheckNotificationPermStatus();
      });
    }
  }

  /// Checks the notification permission status
  Future<String> getCheckNotificationPermStatus() {
    return NotificationPermissions.getNotificationPermissionStatus()
        .then((status) {
      switch (status) {
        case PermissionStatus.denied:
          return permDenied;
        case PermissionStatus.granted:
          return permGranted;
        case PermissionStatus.unknown:
          return permUnknown;
        case PermissionStatus.provisional:
          return permProvisional;
        default:
          return "";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Notification Permissions'),
        ),
        body: Center(
            child: Container(
          margin: EdgeInsets.all(20),
          child: FutureBuilder(
            future: permissionStatusFuture,
            builder: (context, snapshot) {
              // if we are waiting for data, show a progress indicator
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Text('error while retrieving status: ${snapshot.error}');
              }

              if (snapshot.hasData) {
                var textWidget = Text(
                  "The permission status is ${snapshot.data}",
                  style: TextStyle(fontSize: 20),
                  softWrap: true,
                  textAlign: TextAlign.center,
                );
                // The permission is granted, then just show the text
                if (snapshot.data == permGranted) {
                  return textWidget;
                }

                // else, we'll show a button to ask for the permissions
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    textWidget,
                    SizedBox(
                      height: 20,
                    ),
                    MaterialButton(
                      color: Colors.amber,
                      child: Text("Ask for notification status".toUpperCase()),
                      onPressed: () {
                        // show the dialog/open settings screen
                        NotificationPermissions.requestNotificationPermissions(
                                iosSettings: const NotificationSettingsIos(
                                    sound: true, badge: true, alert: true))
                            .then((_) {
                          // when finished, check the permission status
                          setState(() {
                            permissionStatusFuture =
                                getCheckNotificationPermStatus();
                          });
                        });
                      },
                    )
                  ],
                );
              }
              return Text("No permission status yet");
            },
          ),
        )),
      ),
    );
  }
}
