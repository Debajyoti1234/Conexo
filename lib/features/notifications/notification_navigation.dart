import 'package:flutter/material.dart';

import '../chat/chat_repository.dart';
import '../chat/conversation_screen.dart';
import '../profile/privacy_verification_widgets.dart';
import 'notification_models.dart';

/// The single, centralized notification navigation handler.
///
/// [ActivityCenterScreen] stays passive: it renders cards and calls
/// [NotificationNavigation.open()] when tapped. All routing logic lives here,
/// never in the widgets. This keeps the screen trivially swappable for a
/// future backend-driven source without changing its UI.

class NotificationNavigation {
  const NotificationNavigation._();

  static const _repo = LocalChatRepository();

  /// Opens the appropriate screen for a notification, or shows the coming-soon
  /// dialog when the destination is not yet wired.
  static void open(BuildContext context, AppNotification notification) {
    switch (notification.kind) {
      case NotificationKind.request:
        // Connection request accepted → coming soon (no profile reference yet)
        ComingSoonDialog.show(
          context,
          title: 'Connection details',
          message:
              'View their profile and start a conversation when this feature arrives.',
        );
        break;

      case NotificationKind.message:
        // Message received → find the conversation or show coming soon
        final conversation = _repo.findConversationForConnection(notification.id);
        if (conversation != null) {
          Navigator.of(context).push(conversationRoute(conversation));
        } else {
          ComingSoonDialog.show(
            context,
            title: 'Conversation',
            message:
                'Your conversation will appear after your first interaction.',
          );
        }
        break;

      case NotificationKind.join:
      case NotificationKind.plan:
        // Plan joined or plan reminder → find the group chat or show coming soon
        final groupChat = _repo.findConversationForPlan(notification.id);
        if (groupChat != null) {
          Navigator.of(context).push(conversationRoute(groupChat));
        } else {
          ComingSoonDialog.show(
            context,
            title: 'Plan chat',
            message: 'Group chat will open once the plan has participants.',
          );
        }
        break;

      case NotificationKind.system:
        // System notification → coming soon
        ComingSoonDialog.show(
          context,
          title: 'System notification',
          message: 'More details will be available in a future update.',
        );
        break;
    }
  }
}
