import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:lunasea/core/models/notification/unifiedpush_payload.dart';

/// Service managing serverless push notification lifecycle in LunaSea via UnifiedPush.
class UnifiedPushService {
  static final UnifiedPushService _instance = UnifiedPushService._internal();
  factory UnifiedPushService() => _instance;
  UnifiedPushService._internal();

  static const String channelId = 'lunasea_media_alerts';
  static const String channelName = 'LunaSea Media Alerts';
  static const String channelDescription = 'Push alerts from Radarr, Sonarr, and SABnzbd';
  static const String hiveBoxName = 'unifiedpush_settings';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _endpoint;
  String? _distributor;
  bool _isRegistered = false;

  String? get endpoint => _endpoint;
  String? get distributor => _distributor;
  bool get isRegistered => _isRegistered;

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final box = await Hive.openBox(hiveBoxName);
    _endpoint = box.get('endpoint');
    _distributor = box.get('distributor');
    _isRegistered = box.get('is_registered', defaultValue: false);

    UnifiedPush.initialize(
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
      onMessage: _onMessage,
    );
  }

  Future<List<String>> getDistributors() async {
    return await UnifiedPush.getDistributors();
  }

  Future<void> registerApp({String? preferredDistributor}) async {
    final distributors = await getDistributors();
    if (distributors.isEmpty) {
      throw Exception('No UnifiedPush distributor installed. Please install ntfy or NextPush.');
    }

    final targetDistributor = preferredDistributor ?? distributors.first;
    await UnifiedPush.saveDistributor(targetDistributor);
    _distributor = targetDistributor;

    await UnifiedPush.register(instance: 'default');
  }

  Future<void> unregisterApp() async {
    await UnifiedPush.unregister('default');
    _endpoint = null;
    _isRegistered = false;
    final box = await Hive.openBox(hiveBoxName);
    await box.put('is_registered', false);
    await box.delete('endpoint');
  }

  void _onNewEndpoint(PushEndpoint endpoint, String instance) async {
    final endpointUrl = endpoint.url;
    debugPrint('[UnifiedPush] New Endpoint registered: $endpointUrl (Instance: $instance)');
    _endpoint = endpointUrl;
    _isRegistered = true;

    final box = await Hive.openBox(hiveBoxName);
    await box.put('endpoint', endpointUrl);
    await box.put('is_registered', true);
  }

  void _onRegistrationFailed(FailedReason reason, String instance) {
    debugPrint('[UnifiedPush] Registration failed for instance: $instance, reason: $reason');
    _isRegistered = false;
  }

  void _onUnregistered(String instance) async {
    debugPrint('[UnifiedPush] Unregistered from distributor for instance: $instance');
    _endpoint = null;
    _isRegistered = false;
    final box = await Hive.openBox(hiveBoxName);
    await box.put('is_registered', false);
  }

  void _onMessage(PushMessage message, String instance) async {
    try {
      final String rawString = utf8.decode(message.content);
      debugPrint('[UnifiedPush] Incoming raw payload: $rawString');

      Map<String, dynamic> jsonData;
      try {
        jsonData = json.decode(rawString);
      } catch (_) {
        await _showNotification(
          title: 'LunaSea Alert',
          body: rawString,
          payloadTag: 'raw',
        );
        return;
      }

      final event = LunaSeaNotificationEvent.fromJson(jsonData);
      await _recordNotificationInHistory(event);

      await _showNotification(
        title: event.formattedTitle,
        body: event.formattedBody,
        payloadTag: event.sourceTag,
      );
    } catch (e, stack) {
      debugPrint('[UnifiedPush] Error processing message: $e\n$stack');
    }
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    String? payloadTag,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'LunaSea Media Alert',
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      platformDetails,
      payload: payloadTag,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[UnifiedPush] Notification tapped with payload: ${response.payload}');
  }

  Future<void> _recordNotificationInHistory(LunaSeaNotificationEvent event) async {
    try {
      final box = await Hive.openBox('notification_history');
      await box.add(event.toMap());
    } catch (e) {
      debugPrint('[UnifiedPush] Failed to store notification history: $e');
    }
  }
}
