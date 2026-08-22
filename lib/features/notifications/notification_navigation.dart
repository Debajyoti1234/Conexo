import 'package:flutter/material.dart';

import '../chat/chat_models.dart';
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
        // Plan joined / plan activity → open the REAL plan group chat.
        _openPlanChat(context, notification.id);
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

  /// Opens the real Plan group conversation for [planId]. Prefers an existing
  /// conversation; if none exists yet, it is created lazily when the current
  /// user is the creator or a joined participant. Ineligible users get a clear
  /// message — never a "coming soon" placeholder.
  static Future<void> _openPlanChat(
    BuildContext context,
    String planId,
  ) async {
    const chatRepository = ChatRepository();

    String? conversationId;
    String? errorMessage;

    final existing = await chatRepository.findConversationForPlan(planId);
    if (!context.mounted) return;
    if (existing.isSuccess && existing.value != null) {
      conversationId = existing.value!.id;
    } else {
      final created = await chatRepository.getOrCreatePlanConversation(planId);
      if (!context.mounted) return;
      if (created.isSuccess && created.value != null) {
        conversationId = created.value;
      } else {
        errorMessage = created.error ??
            "You are not a member of this plan's group chat.";
      }
    }

    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(errorMessage ?? 'Could not open the plan chat.'),
        ),
      );
      return;
    }

    final preview = ConversationPreview(
      id: conversationId,
      name: 'Plan chat',
      avatarAsset: '',
      lastMessage: '',
      timestamp: '',
      type: ConversationType.group,
      status: ConversationStatus.offline,
      lastMessageType: LastMessageType.plan,
    );

    Navigator.of(context).push(
      conversationRoute(preview, chatRepository: chatRepository),
    );
  }
}
