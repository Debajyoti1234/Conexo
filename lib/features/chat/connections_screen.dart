import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_sections.dart';
import 'chat_widgets.dart';
import 'chat_dtos.dart';
import 'conversation_screen.dart';
import 'realtime_messages_service.dart';
import '../../core/supabase/auth_service.dart';
import '../profile/connections_view_model.dart';
import '../profile/realtime_connections_service.dart';

String _formatInboxTimestamp(DateTime local) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  final daysDiff = today.difference(messageDay).inDays;

  if (daysDiff == 0) {
    final minutesDiff = now.difference(local).inMinutes;
    if (minutesDiff < 1) return 'now';
    if (minutesDiff < 60) return '${minutesDiff}m';
    return '${now.difference(local).inHours}h';
  } else if (daysDiff == 1) {
    return 'Yesterday';
  } else if (daysDiff < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  } else {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]}';
  }
}

class ConnectionsInboxScreen extends StatefulWidget {
  const ConnectionsInboxScreen({super.key});

  @override
  State<ConnectionsInboxScreen> createState() => _ConnectionsInboxScreenState();
}

class _ConnectionsInboxScreenState extends State<ConnectionsInboxScreen> {
  final _chatRepository = const ChatRepository();
  final _repository = const LocalChatRepository();
  final _searchController = TextEditingController();

  List<ConversationPreview> _connections = const [];
  List<ConversationPreview> _plans = const [];
  int _tabIndex = 0;
  String _query = '';
  bool _loading = true;

  late final ConnectionsViewModel _viewModel = const ConnectionsViewModel();
  final Map<String, ConnectionUiModel> _connectionModels = {};
  final Map<String, DateTime> _latestMessageTimes = {};
  final Map<String, String> _conversationToConnectionMap = {};
  final Set<String> _pinnedConnectionIds = <String>{};
  SharedPreferences? _prefs;
  bool _realtimeReady = false;
  final List<ChatMessageEvent> _pendingRealtimeEvents = [];
  final Set<String> _processedMessageIds = {};
  final Set<String> _viewedConversationIds = {};
  bool _suppressUnreadIncrement = false;

  static const _pinnedPrefsKey = 'chat_pinned_ids';

  StreamSubscription<void>? _realtimeSubscription;
  StreamSubscription<ChatMessageEvent>? _messageRealtimeSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeConnectionsService.instance.start();
    _realtimeSubscription =
        RealtimeConnectionsService.instance.onConnectionsChanged.listen((_) {
      if (!mounted || _loading) return;
      _load();
    });
    RealtimeMessagesService.instance.startGlobal();
    _messageRealtimeSubscription =
        RealtimeMessagesService.instance.onGlobalMessageChanged.listen(
      _handleMessageEvent,
    );
  }

  @override
  void dispose() {
    _messageRealtimeSubscription?.cancel();
    _realtimeSubscription?.cancel();
    RealtimeMessagesService.instance.stopGlobal();
    RealtimeConnectionsService.instance.stop();
    _searchController.dispose();
    _viewedConversationIds.clear();
    super.dispose();
  }

  void _handleMessageEvent(ChatMessageEvent event) {
    if (event.type != ChatEventType.inserted) return;
    if (event.message == null) return;

    if (!_realtimeReady) {
      _pendingRealtimeEvents.add(event);
      return;
    }

    _processMessageEvent(event);
  }

  void _processMessageEvent(ChatMessageEvent event) {
    final message = event.message!;

    if (!_processedMessageIds.add(message.id)) return;

    final conversationId = message.conversationId;
    final connectionId = _conversationToConnectionMap[conversationId];
    if (connectionId == null) return;
    if (!_connectionModels.containsKey(connectionId)) return;

    final localCreatedAt = message.createdAt.toLocal();
    final isFromOther = message.senderId != AuthService.currentUser?.id;
    final isCurrentlyViewed = _viewedConversationIds.contains(connectionId);

    setState(() {
      _latestMessageTimes[connectionId] = localCreatedAt;

      final previewIndex = _connections.indexWhere((c) => c.id == connectionId);
      if (previewIndex >= 0) {
        final existing = _connections[previewIndex];
        _connections[previewIndex] = ConversationPreview(
          id: existing.id,
          name: existing.name,
          avatarAsset: existing.avatarAsset,
          lastMessage: message.content,
          timestamp: _formatInboxTimestamp(localCreatedAt),
          type: existing.type,
          status: existing.status,
          lastMessageType: existing.lastMessageType,
          unreadCount: existing.unreadCount +
              ((isFromOther && !isCurrentlyViewed && !_suppressUnreadIncrement)
                  ? 1
                  : 0),
          isTyping: existing.isTyping,
          isPinned: existing.isPinned,
          isMuted: existing.isMuted,
          isVerified: existing.isVerified,
        );
      }

      _connections.sort((a, b) {
        final aTime = _latestMessageTimes[a.id];
        final bTime = _latestMessageTimes[b.id];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    });
  }

  Future<void> _load() async {
    _realtimeReady = false;
    _pendingRealtimeEvents.clear();
    _prefs ??= await SharedPreferences.getInstance();
    _pinnedConnectionIds
      ..clear()
      ..addAll(_prefs!.getStringList(_pinnedPrefsKey) ?? const <String>[]);

    final accepted = await _viewModel.loadAcceptedConnections();
    final plans = await _repository.loadPlanConversations();
    if (!mounted) return;

    final currentUser = AuthService.currentUser;
    final blockedIds = <String>{};
    if (currentUser != null) {
      try {
        final blocked = await Supabase.instance.client
            .from('blocked_users')
            .select('blocked_user_id')
            .eq('blocker_user_id', currentUser.id);
        for (final row in blocked) {
          final id = row['blocked_user_id'] as String?;
          if (id != null) blockedIds.add(id);
        }
      } catch (_) {
        // ignore block load failure — show all connections
      }
    }

    final filtered = accepted.where((m) => !blockedIds.contains(m.otherUserId)).toList();

    _latestMessageTimes.clear();
    final connectionPreviews = <ConversationPreview>[];
    for (final m in filtered) {
      String lastMessage = '';
      String timestamp = '';

      final conversationResult = await _chatRepository.getOrCreateConnectionConversation(m.connectionId);
      if (conversationResult.isSuccess) {
        final conversationId = conversationResult.value!;
        _conversationToConnectionMap[conversationId] = m.connectionId;
        final previewResult = await _chatRepository.getLatestMessagePreview(conversationId);
        if (previewResult.isSuccess && previewResult.value != null) {
          final preview = previewResult.value!;
          lastMessage = preview['content'] as String? ?? '';
          final createdAt = preview['created_at'] as String?;
          if (createdAt != null) {
            final local = DateTime.parse(createdAt).toLocal();
            _latestMessageTimes[m.connectionId] = local;
            timestamp = _formatInboxTimestamp(local);
          }
        }
        final unreadResult = await _chatRepository.loadUnreadCount(conversationId);
        final unreadCount = unreadResult.isSuccess ? (unreadResult.value ?? 0) : 0;
        connectionPreviews.add(ConversationPreview(
          id: m.connectionId,
          name: m.otherUserName,
          avatarAsset: m.otherUserPortrait ?? '',
          lastMessage: lastMessage,
          timestamp: timestamp,
          type: ConversationType.private,
          status: ConversationStatus.recentlyConnected,
          lastMessageType: LastMessageType.connectionAccepted,
          unreadCount: unreadCount,
          isPinned: _pinnedConnectionIds.contains(m.connectionId),
          isVerified: m.isVerified,
          otherUserId: m.otherUserId,
        ));
      } else {
        connectionPreviews.add(ConversationPreview(
          id: m.connectionId,
          name: m.otherUserName,
          avatarAsset: m.otherUserPortrait ?? '',
          lastMessage: '',
          timestamp: '',
          type: ConversationType.private,
          status: ConversationStatus.recentlyConnected,
          lastMessageType: LastMessageType.connectionAccepted,
          unreadCount: 0,
          isPinned: _pinnedConnectionIds.contains(m.connectionId),
          isVerified: m.isVerified,
          otherUserId: m.otherUserId,
        ));
      }
    }

    setState(() {
      _connectionModels.clear();
      for (final m in accepted) {
        _connectionModels[m.connectionId] = m;
      }
      _connections = connectionPreviews;
      _connections.sort((a, b) {
        final aTime = _latestMessageTimes[a.id];
        final bTime = _latestMessageTimes[b.id];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      _plans = plans;
      _loading = false;
    });

    _realtimeReady = true;
    _suppressUnreadIncrement = true;
    if (_pendingRealtimeEvents.isNotEmpty) {
      final pending = List<ChatMessageEvent>.from(_pendingRealtimeEvents);
      _pendingRealtimeEvents.clear();
      for (final evt in pending) {
        _processMessageEvent(evt);
      }
    }
    _suppressUnreadIncrement = false;
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
  }

  List<ConversationPreview> get _tabSource =>
      _tabIndex == 0 ? _connections : _plans;

  List<ConversationPreview> get _filtered {
    if (_query.isEmpty) return _tabSource;
    return _tabSource
        .where((c) => c.name.toLowerCase().contains(_query))
        .toList();
  }

  List<ConversationPreview> get _pinned =>
      _filtered.where((c) => c.isPinned).toList();

  List<ConversationPreview> get _recent =>
      _filtered.where((c) => !c.isPinned).toList();

  void _openConversation(ConversationPreview c) async {
    final isConnectionChat = _connectionModels.containsKey(c.id);
    if (isConnectionChat) {
      final connectionId = c.id;
      final result = await _chatRepository.getOrCreateConnectionConversation(
        connectionId,
      );
      if (result.isFailure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to open conversation'),
            backgroundColor: const Color(0xFFFF4D8D),
          ),
        );
        return;
      }

      final conversationId = result.value!;
      _viewedConversationIds.add(connectionId);

      final unreadResult = await _chatRepository.loadUnreadCount(conversationId);
      final unreadCount = unreadResult.isSuccess ? (unreadResult.value ?? 0) : 0;

      final realPreview = ConversationPreview(
        id: conversationId,
        name: c.name,
        avatarAsset: c.avatarAsset,
        lastMessage: '',
        timestamp: '',
        type: ConversationType.private,
        status: ConversationStatus.recentlyConnected,
        lastMessageType: LastMessageType.connectionAccepted,
        unreadCount: unreadCount,
        isVerified: c.isVerified,
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        conversationRoute(realPreview, chatRepository: _chatRepository),
      );
      if (!mounted) return;
      _viewedConversationIds.remove(connectionId);
      _clearUnread(connectionId);
    } else {
      Navigator.of(context).push(conversationRoute(c));
    }
  }

  void _clearUnread(String connectionId) {
    final idx = _connections.indexWhere((c) => c.id == connectionId);
    if (idx < 0) return;
    final existing = _connections[idx];
    if (existing.unreadCount == 0) return;
    setState(() {
      _connections[idx] = ConversationPreview(
        id: existing.id,
        name: existing.name,
        avatarAsset: existing.avatarAsset,
        lastMessage: existing.lastMessage,
        timestamp: existing.timestamp,
        type: existing.type,
        status: existing.status,
        lastMessageType: existing.lastMessageType,
        unreadCount: 0,
        isTyping: existing.isTyping,
        isPinned: existing.isPinned,
        isMuted: existing.isMuted,
        isVerified: existing.isVerified,
      );
    });
  }

  Future<void> _togglePin(ConversationPreview c) async {
    final id = c.id;
    final willPin = !_pinnedConnectionIds.contains(id);
    setState(() {
      if (willPin) {
        _pinnedConnectionIds.add(id);
      } else {
        _pinnedConnectionIds.remove(id);
      }
      final idx = _connections.indexWhere((x) => x.id == id);
      if (idx >= 0) {
        final existing = _connections[idx];
        _connections[idx] = ConversationPreview(
          id: existing.id,
          name: existing.name,
          avatarAsset: existing.avatarAsset,
          lastMessage: existing.lastMessage,
          timestamp: existing.timestamp,
          type: existing.type,
          status: existing.status,
          lastMessageType: existing.lastMessageType,
          unreadCount: existing.unreadCount,
          isTyping: existing.isTyping,
          isPinned: willPin,
          isMuted: existing.isMuted,
          isVerified: existing.isVerified,
        );
      }
    });
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_pinnedPrefsKey, _pinnedConnectionIds.toList());
  }

  void _showConversationActions(ConversationPreview c) {
    final isPinned = _pinnedConnectionIds.contains(c.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ConversationActionsSheet(
        isPinned: isPinned,
        onTogglePin: () {
          Navigator.of(sheetContext).pop();
          _togglePin(c);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnections = _tabIndex == 0;
    final hasResults = _filtered.isNotEmpty;
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                ConnectionsHeader(
                  title: isConnections ? 'Connections' : 'Plans',
                  subtitle: isConnections
                      ? 'Your private conversations, in one calm place.'
                      : 'Group chats from the plans you host and join.',
                ),
                const SizedBox(height: 20),
                ChatSegmentedTabs(
                  selectedIndex: _tabIndex,
                  onChanged: _onTabChanged,
                  connectionsCount: _loading ? null : _connections.length,
                  plansCount: _loading ? null : _plans.length,
                ),
                const SizedBox(height: 20),
                PremiumSearchBar(
                  controller: _searchController,
                  hint: isConnections
                      ? 'Search connections'
                      : 'Search plan chats',
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .06),
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildBody(
                    key: ValueKey('tab-$_tabIndex-$isSearching-$hasResults'),
                    isConnections: isConnections,
                    hasResults: hasResults,
                    isSearching: isSearching,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required Key key,
    required bool isConnections,
    required bool hasResults,
    required bool isSearching,
  }) {
    if (_loading) {
      return const LoadingSkeleton(key: ValueKey('loading'));
    }

    if (!hasResults) {
      return EmptyInbox(
        key: key,
        isSearch: isSearching,
        emptyIcon:
            isConnections ? Icons.forum_outlined : Icons.groups_2_outlined,
        emptyTitle: isConnections
            ? 'No conversations yet'
            : 'No plan chats yet',
        emptyBody: isConnections
            ? 'When you connect with people, your chats appear here.'
            : 'Join or host a plan to start a group chat.',
      );
    }

    final onLongPress = isConnections ? _showConversationActions : null;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pinned.isNotEmpty) ...[
          PinnedConversationsSection(
            conversations: _pinned,
            onOpen: _openConversation,
            onLongPress: onLongPress,
          ),
          const SizedBox(height: 24),
        ],
        RecentConversationsSection(
          conversations: _recent,
          onOpen: _openConversation,
          showLabel: _pinned.isNotEmpty,
          onLongPress: onLongPress,
        ),
      ],
    );
  }
}

class _ConversationActionsSheet extends StatelessWidget {
  const _ConversationActionsSheet({
    required this.isPinned,
    required this.onTogglePin,
  });

  final bool isPinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161C30),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                onTap: onTogglePin,
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: const Color(0xFFB7A5FF),
                  size: 22,
                ),
                title: Text(
                  isPinned ? 'Unpin chat' : 'Pin chat',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
