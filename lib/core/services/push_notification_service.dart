import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_repository.dart';
import '../../features/chat/conversation_screen.dart';
import '../../core/supabase/auth_service.dart';
import 'app_navigator.dart';
import 'fcm_token_service.dart';

abstract final class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _firebaseAvailable = false;

  static const String _channelId = 'conexo_messages';
  static const String _channelName = 'Conexo Messages';
  static const String _channelDescription =
      'Notifications for new chat messages';

  static Future<bool> initialize() async {
    if (_initialized) return _firebaseAvailable;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint('PushNotificationService: Firebase unavailable: $e');
      return false;
    }

    if (kIsWeb) return true;

    try {
      await _initLocalNotifications();
      await _ensureChannel(_localNotifications);
      await _requestPermission();
      await FcmTokenService.start();
      await _configureMessageHandlers();
    } catch (e) {
      debugPrint('PushNotificationService initialize error: $e');
    }

    return true;
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onLocalNotificationTap(response.payload);
      },
    );
  }

  static Future<void> _ensureChannel(
      FlutterLocalNotificationsPlugin plugin) async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('PushNotificationService permission: '
        '${settings.authorizationStatus}');
    debugPrint('PushNotificationService permission details: '
        'alert=${settings.alert}, badge=${settings.badge}, '
        'sound=${settings.sound}');
  }

  static Future<void> _configureMessageHandlers() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      onLocalNotificationTap(launchDetails!.notificationResponse?.payload);
    }

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(initialMessage.data);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data);
    });
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    if (type != 'connection_message' && type != 'plan_message') {
      return;
    }

    final conversationId = data['conversation_id'];
    if (conversationId is String && conversationId == _activeConversationId) {
      return;
    }

    await _showMessageNotification(_localNotifications, message);
  }

  static Future<void> _showMessageNotification(
    FlutterLocalNotificationsPlugin plugin,
    RemoteMessage message,
  ) async {
    final data = message.data;
    final type = data['type'];
    if (type != 'connection_message' && type != 'plan_message') return;

    final rawTitle = data['title'];
    final title = (rawTitle is String && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Conexo';

    final rawBody = data['body'];
    final body = (rawBody is String && rawBody.trim().isNotEmpty)
        ? rawBody.trim()
        : 'You have a new message';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: const Color(0xFF7C3AED),
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(body),
    );

    await plugin.show(
      id: message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  static void _handleTap(Map<String, dynamic> data) {
    final type = data['type'];
    final conversationId = data['conversation_id'];
    if (conversationId is! String || conversationId.isEmpty) return;

    if (type == 'connection_message') {
      _openConnectionChat(conversationId);
    } else if (type == 'plan_message') {
      _openPlanChat(
        planId: data['plan_id'] as String?,
        conversationId: conversationId,
      );
    }
  }

  static Future<void> _openConnectionChat(String conversationId) async {
    final context = AppNavigator.instance.key.currentContext;
    if (context == null) return;

    String? otherUserId;
    String name = '';
    try {
      final me = AuthService.currentUser?.id;
      final members = await Supabase.instance.client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .limit(2);
      for (final m in members) {
        final uid = m['user_id'] as String?;
        if (uid != null && uid != me) {
          otherUserId = uid;
          break;
        }
      }
      if (otherUserId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('display_name')
            .eq('id', otherUserId)
            .maybeSingle();
        final dn = profile?['display_name'] as String?;
        if (dn != null && dn.isNotEmpty) name = dn;
      }
    } catch (_) {}

    final preview = ConversationPreview(
      id: conversationId,
      name: name,
      avatarAsset: '',
      lastMessage: '',
      timestamp: '',
      type: ConversationType.private,
      status: ConversationStatus.recentlyConnected,
      lastMessageType: LastMessageType.text,
      unreadCount: 0,
      otherUserId: otherUserId,
    );

    AppNavigator.instance.key.currentState?.push(
      conversationRoute(preview, chatRepository: const ChatRepository()),
    );
  }

  static Future<void> _openPlanChat({
    required String? planId,
    required String conversationId,
  }) async {
    final context = AppNavigator.instance.key.currentContext;
    if (context == null) return;

    String name = '';
    try {
      final id = planId ?? conversationId;
      final plan = await Supabase.instance.client
          .from('plans')
          .select('title')
          .eq('id', id)
          .maybeSingle();
      final t = plan?['title'] as String?;
      if (t != null && t.isNotEmpty) name = t;
    } catch (_) {}

    final preview = ConversationPreview(
      id: conversationId,
      name: name,
      avatarAsset: '',
      lastMessage: '',
      timestamp: '',
      type: ConversationType.group,
      status: ConversationStatus.offline,
      lastMessageType: LastMessageType.plan,
      planId: planId,
    );

    AppNavigator.instance.key.currentState?.push(
      conversationRoute(preview, chatRepository: const ChatRepository()),
    );
  }

  static void onLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _handleTap(data);
    } catch (_) {}
  }

  static Future<void> stop() async {
    await FcmTokenService.stop();
  }

  static String? _activeConversationId;

  static void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
}
