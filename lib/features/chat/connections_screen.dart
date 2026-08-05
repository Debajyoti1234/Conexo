import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_sections.dart';
import 'chat_widgets.dart';
import 'conversation_screen.dart';

/// The premium Chat home (Phases 6.1–6.3).
///
/// Two premium segmented tabs share one screen, one search field, and one
/// data source ([LocalChatRepository]):
///
///   • **Connections** — private one-to-one chats only.
///   • **Plans** — plan group chats only.
///
/// Each tab keeps independent data, its own pinned/recent grouping, and a
/// tab-specific empty state. Tapping any conversation opens the shared
/// [ConversationScreen]. UI-only: no messaging, no backend.
class ConnectionsInboxScreen extends StatefulWidget {
  const ConnectionsInboxScreen({super.key});

  @override
  State<ConnectionsInboxScreen> createState() => _ConnectionsInboxScreenState();
}

class _ConnectionsInboxScreenState extends State<ConnectionsInboxScreen> {
  final _repository = const LocalChatRepository();
  final _searchController = TextEditingController();

  List<ConversationPreview> _connections = const [];
  List<ConversationPreview> _plans = const [];
  int _tabIndex = 0;
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final connections = await _repository.loadConnectionConversations();
    final plans = await _repository.loadPlanConversations();
    if (!mounted) return;
    setState(() {
      _connections = connections;
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

  /// The conversations backing the currently-selected tab.
  List<ConversationPreview> get _tabSource =>
      _tabIndex == 0 ? _connections : _plans;

  /// Instant local filtering — checks name only, within the active tab.
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

  void _openConversation(ConversationPreview c) {
    Navigator.of(context).push(conversationRoute(c));
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
                // AnimatedSwitcher gives a soft cross-fade between tabs while
                // keeping each tab's content keyed for correct rebuilds.
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
