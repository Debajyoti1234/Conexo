import 'package:flutter/material.dart';

import '../chat/chat_models.dart';
import '../chat/chat_repository.dart';
import '../chat/conversation_screen.dart';
import '../main_shell.dart';
import '../plans/invitation_details_screen.dart';
import '../plans/plan_details_data.dart';
import '../plans/supabase_plan_repository.dart';
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

  /// Opens the appropriate screen for a notification, or shows the coming-soon
  /// dialog when the destination is not yet wired.
  static void open(BuildContext context, AppNotification notification) {
    switch (notification.kind) {
      case NotificationKind.request:
        Navigator.of(context).pop();
        MainShell.switchToTab(2);
        break;

      case NotificationKind.message:
        // Message received → open the connection conversation.
        _openConnectionChat(context, notification);
        break;

      case NotificationKind.join:
      case NotificationKind.plan:
        // Plan joined / plan activity → open the REAL plan group chat.
        _openPlanChat(context, notification.entityId ?? notification.id);
        break;

      case NotificationKind.planInvitation:
        // The accepted-plan notification reuses the plan_invitation kind but
        // carries entity_type = 'plan_chat' and must open the existing Plan
        // Chat directly. A true pending invitation carries entity_type = 'plan'
        // and opens the invitation preview.
        if (notification.entityType == 'plan_chat' &&
            notification.entityId != null) {
          _openPlanChat(context, notification.entityId!);
        } else {
          _openInvitationDetails(context, notification);
        }
        break;

      case NotificationKind.system:
        if (notification.entityType == 'plan_chat' &&
            notification.entityId != null) {
          _openPlanChat(context, notification.entityId!);
          break;
        }
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

  static Future<void> _openConnectionChat(
    BuildContext context,
    AppNotification notification,
  ) async {
    final connectionId = notification.entityId ?? notification.id;
    final chatRepository = ChatRepository();

    final result = await chatRepository.getOrCreateConnectionConversation(connectionId);
    if (!context.mounted) return;

    final conversationId = result.value;
    final errorMessage = result.error;

    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(errorMessage ?? 'Could not open the conversation.'),
        ),
      );
      return;
    }

    final preview = ConversationPreview(
      id: conversationId,
      name: notification.title,
      avatarAsset: '',
      lastMessage: notification.subtitle,
      timestamp: notificationTimeLabel(notification.timestamp),
      type: ConversationType.private,
      status: ConversationStatus.recentlyConnected,
      lastMessageType: LastMessageType.connectionAccepted,
      unreadCount: 0,
    );

    Navigator.of(context).push(
      conversationRoute(preview, chatRepository: chatRepository),
    );
  }

  static Future<void> _openInvitationDetails(
    BuildContext context,
    AppNotification notification,
  ) async {
    final planId = notification.entityId;
    if (planId == null) {
      _showInvitationUnavailable(context);
      return;
    }

    final repo = const SupabasePlanRepository();
    List<PlanInvitation> invitations;
    try {
      invitations = await repo.getPendingInvitations();
    } catch (_) {
      if (!context.mounted) return;
      _showInvitationUnavailable(context);
      return;
    }
    if (!context.mounted) return;

    PlanInvitation? match;
    for (final invite in invitations) {
      if (invite.planId == planId) {
        match = invite;
        break;
      }
    }

    // The invitation may have already been accepted, declined, or withdrawn.
    if (match == null) {
      _showInvitationUnavailable(context);
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvitationDetailsScreen(
          invitation: match!,
          repository: repo,
        ),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation updated'),
          backgroundColor: Color(0xFF47D7A5),
        ),
      );
    }
  }

  static void _showInvitationUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('This invitation is no longer available.'),
      ),
    );
  }
}
