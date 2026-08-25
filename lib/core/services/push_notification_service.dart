import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_repository.dart';
import '../../features/chat/conversation_screen.dart';
import '../../features/main_shell.dart';
import '../../features/plans/invitation_details_screen.dart';
import '../../features/plans/plan_details_data.dart';
import '../../features/plans/supabase_plan_repository.dart';
import '../../core/supabase/auth_service.dart';
import 'app_navigator.dart';
import 'fcm_token_service.dart';
import 'firebase_initializer.dart';
import 'permission_manager.dart';
import 'web_fcm_diagnostics.dart';
import 'web_notification_presenter.dart';

abstract final class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _firebaseAvailable = false;
  static bool _webPermissionRequested = false;

  static const String _channelId = 'conexo_messages';
  static const String _channelName = 'Conexo Messages';
  static const String _channelDescription =
      'Notifications for new chat messages';

  static Future<bool> initialize() async {
    if (_initialized) return _firebaseAvailable;
    _initialized = true;

    debugPrint('CONEXO_PERMISSION_DIAG push_initialize_started');
    debugPrint('CONEXO_PERMISSION_DIAG authenticated='
        '${AuthService.currentUser != null}');

    _firebaseAvailable = await FirebaseInitializer.ensureInitialized();
    if (!_firebaseAvailable) {
      debugPrint('PushNotificationService: Firebase unavailable, FCM disabled');
      return false;
    }

    if (kIsWeb) {
      await _initializeWeb();
      return true;
    }

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

  static Future<void> requestNotificationPermission() async {
    if (!kIsWeb) return;
    if (_webPermissionRequested) return;
    _webPermissionRequested = true;

    debugPrint('CONEXO_IOS_WEB_FCM_DIAG permission_flow_started');
    debugPrint('CONEXO_IOS_WEB_FCM_DIAG notification_permission_before=${getCurrentWebNotificationPermission()}');
    debugPrint('CONEXO_IOS_WEB_FCM_DIAG permission_request_started');
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('CONEXO_IOS_WEB_FCM_DIAG permission_result=${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('CONEXO_IOS_WEB_FCM_DIAG permission_request_error=$e');
    }

    await FcmTokenService.start();
    await logWebFcmDiagnostics();
  }

  static Future<void> _initializeWeb() async {
    try {
      debugPrint('CONEXO_IOS_WEB_FCM_DIAG firebase_initialized=YES');
      try {
        final supported = await FirebaseMessaging.instance.isSupported();
        debugPrint('CONEXO_IOS_WEB_FCM_DIAG firebase_messaging_supported=$supported');
      } catch (e) {
        debugPrint('CONEXO_IOS_WEB_FCM_DIAG firebase_messaging_supported_error=$e');
      }

      await logIosWebFcmSetupDiagnostics();

      await logWebFcmDiagnostics();

      FirebaseMessaging.onMessage.listen(_onForegroundMessageWeb);

      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleTap(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleTap(initial.data);
    } catch (e) {
      debugPrint('CONEXO_FCM_WEB_DIAG web_init_error=$e');
    }
  }

  static Future<void> _onForegroundMessageWeb(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    debugPrint('CONEXO_WEB_FCM_DIAG foreground_message_received type=$type');
    debugPrint('CONEXO_IOS_WEB_FCM_DIAG foreground message_received type=$type '
        'conversation_id_present=${data['conversation_id'] is String}');

    if (type == 'connection_message' || type == 'plan_message') {
      final conversationId = data['conversation_id'];
      if (conversationId is String && conversationId == _activeConversationId) {
        return;
      }

      final notification = message.notification;
      final rawTitle = notification?.title ?? data['title'];
      final title = (rawTitle is String && rawTitle.trim().isNotEmpty)
          ? rawTitle.trim()
          : 'Conexo';
      final rawBody = notification?.body ?? data['body'];
      final body = (rawBody is String && rawBody.trim().isNotEmpty)
          ? rawBody.trim()
          : 'You have a new message';

      await showWebNotification(
        title: title,
        body: body,
        tag: conversationId is String ? conversationId : null,
      );
      return;
    }

    if (type == 'connection_request' || type == 'request_accepted' ||
        type == 'plan_invitation' || type == 'join_request') {
      final notification = message.notification;
      final rawTitle = notification?.title ?? data['title'];
      final title = (rawTitle is String && rawTitle.trim().isNotEmpty)
          ? rawTitle.trim()
          : 'Conexo';
      final rawBody = notification?.body ?? data['body'];
      final body = (rawBody is String && rawBody.trim().isNotEmpty)
          ? rawBody.trim()
          : 'You have a new notification';

      final entityId = data['entity_id'];
      await showWebNotification(
        title: title,
        body: body,
        tag: entityId is String ? entityId : null,
      );
    }
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
    debugPrint('CONEXO_PERMISSION_DIAG request_permission_started');
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+ (API 33+) requires the POST_NOTIFICATIONS runtime
        // permission. Route this through permission_handler — the exact same
        // mechanism the app already uses for the location prompt — which
        // reliably surfaces the system dialog. FirebaseMessaging's
        // requestPermission() does not reliably show the POST_NOTIFICATIONS
        // dialog on Android and can be silently dropped when another runtime
        // permission dialog (location) is requested concurrently at sign-in.
        final before =
            await PermissionManager.check(PermissionType.notifications);
        debugPrint('CONEXO_PERMISSION_DIAG android_status_before=$before');
        var status = before;
        if (before != PermissionStatus.granted) {
          status =
              await PermissionManager.request(PermissionType.notifications);
        }
        debugPrint('CONEXO_PERMISSION_DIAG authorization_status=$status');
      } else {
        // iOS / other platforms: FirebaseMessaging drives the APNs
        // authorization prompt.
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('CONEXO_PERMISSION_DIAG authorization_status='
            '${settings.authorizationStatus}');
      }
    } catch (e) {
      debugPrint('CONEXO_PERMISSION_DIAG request_permission_error=$e');
    }
    debugPrint('CONEXO_PERMISSION_DIAG request_permission_finished');
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

    if (type == 'connection_message' || type == 'plan_message') {
      final conversationId = data['conversation_id'];
      if (conversationId is String && conversationId == _activeConversationId) {
        return;
      }
      await _showMessageNotification(_localNotifications, message);
      return;
    }

    if (type == 'connection_request' || type == 'request_accepted' ||
        type == 'plan_invitation' || type == 'join_request') {
      await _showEventNotification(_localNotifications, message);
    }
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

  static Future<void> _showEventNotification(
    FlutterLocalNotificationsPlugin plugin,
    RemoteMessage message,
  ) async {
    final data = message.data;
    final rawTitle = data['title'];
    final title = (rawTitle is String && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Conexo';

    final rawBody = data['body'];
    final body = (rawBody is String && rawBody.trim().isNotEmpty)
        ? rawBody.trim()
        : 'You have a new notification';

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

    if (type == 'connection_message') {
      final conversationId = data['conversation_id'];
      if (conversationId is String && conversationId.isNotEmpty) {
        _openConnectionChat(conversationId);
      }
    } else if (type == 'plan_message') {
      final conversationId = data['conversation_id'];
      if (conversationId is String && conversationId.isNotEmpty) {
        _openPlanChat(
          planId: data['plan_id'] as String?,
          conversationId: conversationId,
        );
      }
    } else if (type == 'connection_request' || type == 'request_accepted' || type == 'join_request') {
      _openConnectionsTab();
    } else if (type == 'plan_invitation') {
      // A membership-success push reuses the plan_invitation type but carries
      // entity_type = 'plan_chat' and must open the Plan Chat directly. A true
      // pending invitation carries entity_type = 'plan' and opens the
      // invitation preview. This mirrors the in-app Activity routing.
      final entityType = data['entity_type'];
      if (entityType == 'plan_chat') {
        _openPlanChatFromPush(data['entity_id'] as String?);
      } else {
        _openInvitationFromPush(data);
      }
    }
  }

  static void _openConnectionsTab() {
    MainShell.switchToTab(2);
  }

  static Future<void> _openPlanChatFromPush(String? planId) async {
    if (planId == null || planId.isEmpty) {
      _openConnectionsTab();
      return;
    }

    const chatRepository = ChatRepository();
    String? conversationId;

    try {
      final existing = await chatRepository.findConversationForPlan(planId);
      if (existing.isSuccess && existing.value != null) {
        conversationId = existing.value!.id;
      } else {
        final created =
            await chatRepository.getOrCreatePlanConversation(planId);
        if (created.isSuccess && created.value != null) {
          conversationId = created.value;
        }
      }
    } catch (_) {
      _openConnectionsTab();
      return;
    }

    if (conversationId == null) {
      _openConnectionsTab();
      return;
    }

    await _openPlanChat(planId: planId, conversationId: conversationId);
  }

  static Future<void> _openInvitationFromPush(Map<String, dynamic> data) async {
    final planId = data['entity_id'] as String?;
    if (planId == null || planId.isEmpty) {
      _openConnectionsTab();
      return;
    }

    final context = AppNavigator.instance.key.currentContext;
    if (context == null) {
      _openConnectionsTab();
      return;
    }

    final repo = const SupabasePlanRepository();
    List<PlanInvitation> invitations;
    try {
      invitations = await repo.getPendingInvitations();
    } catch (_) {
      _openConnectionsTab();
      return;
    }

    PlanInvitation? match;
    for (final invite in invitations) {
      if (invite.planId == planId) {
        match = invite;
        break;
      }
    }

    if (match == null) {
      _openConnectionsTab();
      return;
    }

    AppNavigator.instance.key.currentState?.push(
      MaterialPageRoute(
        builder: (_) => InvitationDetailsScreen(
          invitation: match!,
          repository: repo,
        ),
      ),
    );
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
    String avatarAsset = '';
    try {
      final id = planId ?? conversationId;
      final plan = await Supabase.instance.client
          .from('plans')
          .select('title, cover_url')
          .eq('id', id)
          .maybeSingle();
      final t = plan?['title'] as String?;
      if (t != null && t.isNotEmpty) name = t;
      // Resolve the plan cover exactly like the canonical Plan Chat list flow
      // (SupabasePlanRepository.getCoverSignedUrl against the plan-covers
      // bucket) so the header shows the real Plan picture, not a letter
      // fallback. Member count/messages are already loaded by ConversationScreen
      // from the same conversation id.
      final coverPath = plan?['cover_url'] as String?;
      final signedCover =
          await const SupabasePlanRepository().getCoverSignedUrl(coverPath);
      if (signedCover != null && signedCover.isNotEmpty) {
        avatarAsset = signedCover;
      }
    } catch (_) {}

    final preview = ConversationPreview(
      id: conversationId,
      name: name,
      avatarAsset: avatarAsset,
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
