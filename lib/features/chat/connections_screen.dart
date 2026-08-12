import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_sections.dart';
import 'chat_widgets.dart';
import 'conversation_screen.dart';
import '../profile/connections_view_model.dart';
import '../profile/realtime_connections_service.dart';

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeSubscription?.cancel();
    RealtimeConnectionsService.instance.stop();
    super.dispose();
  }

  StreamSubscription<void>? _realtimeSubscription;

  Future<void> _load() async {
    final accepted = await _viewModel.loadAcceptedConnections();
    final plans = await _repository.loadPlanConversations();
    if (!mounted) return;
    setState(() {
      _connectionModels.clear();
      for (final m in accepted) {
        _connectionModels[m.connectionId] = m;
      }
      _connections = accepted
          .map((m) => ConversationPreview(
                id: m.connectionId,
                name: m.otherUserName,
                avatarAsset: m.otherUserPortrait ?? '',
                lastMessage: '',
                timestamp: '',
                type: ConversationType.private,
                status: ConversationStatus.recentlyConnected,
                lastMessageType: LastMessageType.connectionAccepted,
                unreadCount: 0,
                isVerified: m.isVerified,
              ))
          .toList();
      _plans = plans;
      _loading = false;
    });
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
      Navigator.of(context).push(
        conversationRoute(realPreview, chatRepository: _chatRepository),
      );
    } else {
      Navigator.of(context).push(conversationRoute(c));
    }
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
                const SizedBox(height: 24),
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

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pinned.isNotEmpty) ...[
          PinnedConversationsSection(
            conversations: _pinned,
            onOpen: _openConversation,
          ),
          const SizedBox(height: 24),
        ],
        RecentConversationsSection(
          conversations: _recent,
          onOpen: _openConversation,
          showLabel: _pinned.isNotEmpty,
        ),
      ],
    );
  }
}
