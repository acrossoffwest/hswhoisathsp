import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class LocalNoticeService {
  final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> setup() async {
    const androidSetting = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSetting = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidSetting, iOS: iosSetting);
    await _localNotificationsPlugin.initialize(initSettings).then((_) {
      debugPrint('setupPlugin: setup success');
    }).catchError((Object error) {
      debugPrint('Error: $error');
    });

    // ./cringecast-client --mqtt-url=tcp://130.61.124.111:1883 --mqtt-password=zarazcipodam1234
    final mqttClient = await connectToMqtt(
      broker: '130.61.124.111',
      username: 'admin',
      password: 'zarazcipodam1234',
    );
    mqttClient.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messageList) {
      final message = messageList[0].payload as MqttPublishMessage;
      final payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);

      handleMessage(payload);
    });

    subscribeToTopic(mqttClient, 'cringecast');
  }

  void handleMessage(String payload) {
    Map<String, dynamic> obj;
    try {
      obj = jsonDecode(payload);
    } catch (e) {
      print('Error decoding JSON: $e');
      return;
    }

    switch (obj['command']) {
      case 'say':
        final sayPayload = jsonDecode(obj['payload']);
        say(sayPayload);
        break;
      case 'play':
        final audioUrl = obj['payload'];
        playAudio(audioUrl);
        break;
    // case 'stop':
    //   stopPlaying = true;
    //   break;
      default:
        print('Unknown command received');
    }
  }

  void say(Map<String, dynamic> sayPayload) async {
    FlutterTts flutterTts = FlutterTts();

    List<String> sentences =
    splitToSentences(sayPayload['query'], 100, sayPayload['language']);

    await flutterTts.setLanguage(sayPayload['language']);

    for (String sentence in sentences) {
      await flutterTts.speak(sentence);
    }
  }

  List<String> splitToSentences(String text, int maxLength, String language) {
    List<String> sentences = text.split('.');
    sentences = sentences.map((sentence) => sentence.trim()).toList();

    List<String> merged = [];
    String current = '';

    for (String sentence in sentences) {
      if (current.length + sentence.length + 1 <= maxLength) {
        if (current.isNotEmpty) {
          current += ' ';
        }
        current += sentence;
      } else {
        merged.add(current);
        current = sentence;
      }
    }

    if (current.isNotEmpty) {
      merged.add(current);
    }

    return merged;
  }

  Future<void> playAudio(String url) async {
    AudioPlayer audioPlayer = AudioPlayer(
      mode: PlayerMode.MEDIA_PLAYER,
    );

    // Handle errors
    audioPlayer.onPlayerError.listen((msg) {
      print('Audio player error : $msg');
    });

    // Play the audio file from the given URL
    // await audioPlayer.setUrl(url);
    await audioPlayer.play(url);
  }

  Future<MqttServerClient> connectToMqtt({
    required String broker,
    required String username,
    required String password,
  }) async {
    final clientId = _generateClientId();
    final mqttClient = MqttServerClient.withPort(broker, clientId, 1883);
    mqttClient.logging(on: false);
    mqttClient.keepAlivePeriod = 30;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(username, password)
        .keepAliveFor(30)
        .withWillTopic('cringecast/status')
        .withWillMessage('Client disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    mqttClient.connectionMessage = connMessage;

    try {
      await mqttClient.connect();
      print('Connected to MQTT broker');
    } on NoConnectionException catch (e) {
      print('NoConnectionException: ${e.toString()}');
      mqttClient.disconnect();
    } on SocketException catch (e) {
      print('SocketException: ${e.toString()}');
      mqttClient.disconnect();
    }

    return mqttClient;
  }

  Future<void> subscribeToTopic(
      MqttServerClient mqttClient,
      String topic,
      ) async {
    mqttClient.subscribe(topic, MqttQos.atLeastOnce);
    print('Subscribed to topic: $topic');
  }

  String _generateClientId() {
    final random = Random();
    return 'mqtt_subscriber_${random.nextInt(10000)}';
  }

  void notify (String title, String body, String channel) async {
    final androidDetail = AndroidNotificationDetails(
        channel, // channel Id
        channel  // channel Name
    );
    final iosDetail = DarwinNotificationDetails();

    final noticeDetail = NotificationDetails(
      iOS: iosDetail,
      android: androidDetail,
    );
    final id = 0;
    await _localNotificationsPlugin.show(id, title, body, noticeDetail);
  }
}