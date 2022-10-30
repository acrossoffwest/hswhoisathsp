import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:appwidgetflutter/model/WhoIsAtHsp.dart';

import 'lib/local_notice_service.dart';

final observedUsersController = TextEditingController(text: "");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNoticeService().setup();
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  runApp(MyApp());
}

Future<http.Response> loadCarbonLife() {
  return http.get(Uri.parse('https://whois.at.hsp.sh/api/now')).timeout(
    const Duration(seconds: 3),
    onTimeout: () {
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
  throw Exception('Something went wrong!');
}

void observedUserOnline(String user) {
  LocalNoticeService().notify(
    "Online Notifier",
    "User(s): \"${user}\" is online",
    "observedUser",
  );
}

void checkObservedUserInNewResponse (String observedUsersString, List<String> users) {
  List<String> observedUsers = observedUsersString.split(",").map((e) => e.trim()).toList();
  List<String> onlineUsers = [];
  users.add("test");
  users.add("test 1");
  List<String> usersWithLowerCase = users.map((e) => e.toLowerCase()).toList();
  log(observedUsersString);
  observedUsers.forEach((user) {
    if (usersWithLowerCase.contains(user.toLowerCase())) {
      onlineUsers.add(user);
    }
  });
  if (onlineUsers.isNotEmpty) {
    observedUserOnline(onlineUsers.join(", "));
  }
}

// Called when Doing Background Work initiated from Widget
Future<void> backgroundCallback(Uri uri) async {
  if (uri.host == 'updatecounter') {
    await HomeWidget.saveWidgetData<bool>('_isLoading', true);
    await HomeWidget.updateWidget(name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
    final whoIsAtHsp = await fetchCarbonLife();
    checkObservedUserInNewResponse(observedUsersController.value.text, whoIsAtHsp.users);
    await HomeWidget.saveWidgetData<int>('_counter', whoIsAtHsp.getUsersLength());
    await HomeWidget.saveWidgetData<String>('_carbonLife', whoIsAtHsp.getUsersListAsString());
    await HomeWidget.saveWidgetData<bool>('_isLoading', false);
    await HomeWidget.updateWidget(name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
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
        backgroundColor: Colors.black
      ),
      home: MyHomePage(title: 'HS: Who is at HSP'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

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

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String _carbonLife = "";
  bool _isLoading = false;
  Timer reloadTimer = null;

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri uri) => loadData());
    loadData(); // This will load data from widget every time app is opened
  }

  void loadData() async {
    _counter = await HomeWidget.getWidgetData<int>('_counter', defaultValue: 0);
    _carbonLife = await HomeWidget.getWidgetData<String>('_carbonLife', defaultValue: "");
    _isLoading = await HomeWidget.getWidgetData<bool>('_isLoading', defaultValue: false);
    setState(() {});
  }

  Future<void> updateAppWidget() async {
    await HomeWidget.saveWidgetData<bool>('_isLoading', _isLoading);
    await HomeWidget.saveWidgetData<int>('_counter', _counter);
    await HomeWidget.saveWidgetData<String>('_carbonLife', _carbonLife);
    await HomeWidget.updateWidget(name: 'AppWidgetProvider', iOSName: 'AppWidgetProvider');
  }

  Future<Void> _refreshData() async {
    reInitReloader();
    setState(() => {
      _isLoading = true
    });
    final WhoIsAtHsp whoIsAtHsp = await fetchCarbonLife();

    checkObservedUserInNewResponse(observedUsersController.value.text, whoIsAtHsp.users);

    setState(() => {
      _counter = whoIsAtHsp.getUsersLength(),
      _carbonLife = whoIsAtHsp.getUsersListAsString(),
      _isLoading = false,
    });
    updateAppWidget();
  }

  void reInitReloader () {
    if (reloadTimer != null) {
      reloadTimer.cancel();
    }
    const reloadMinutes = Duration(minutes: 10);
    reloadTimer = Timer.periodic(reloadMinutes, (Timer t) => print('hi!'));
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
            children: !_isLoading ? <Widget>[
              Row(
                children: [
                  Text(
                      'There are $_counter carbon-based lifeforms in HS according to our measurements.',
                      style: TextStyle(
                          color: Colors.white
                      ),
                      textAlign: TextAlign.start
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$_carbonLife',
                    style: TextStyle(
                        color: Colors.white
                    ),
                    textAlign: TextAlign.start,
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
                        labelText: 'Who are you waiting for? (Type users name by comma separated)',
                        labelStyle: TextStyle(
                            color: Colors.white
                        ),
                      ),
                      style: TextStyle(
                          color: Colors.green
                      ),
                    ),
                  ),
                ],
              ),
            ] : <Widget>[
              Row(
                children: [
                  Text(
                      'Loading...',
                      style: TextStyle(
                          color: Colors.white
                      ),
                      textAlign: TextAlign.start
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: OutlinedButton(
        child: Text(
          'Refresh',
          style: TextStyle(
              color: Color(0xFFFFFFFF)
          ),
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
