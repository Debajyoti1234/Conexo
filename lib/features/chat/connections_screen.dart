import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_sections.dart';
import 'chat_widgets.dart';
import 'conversation_screen.dart';

/// The premium Connections inbox (Phase 6.1).
///
/// UI-only: loads demo conversations, supports instant local search, and
/// groups pinned vs recent. Tapping a conversation opens the premium
/// [ConversationScreen] (Phase 6.2). No Plans, no backend.
class ConnectionsInboxScreen extends StatefulWidget {
  const ConnectionsInboxScreen({super.key});

  @override
  State<ConnectionsInboxScreen> createState() => _ConnectionsInboxScreenState();
}

class _ConnectionsInboxScreenState extends State<ConnectionsInboxScreen> {
  final _repository = const LocalChatRepository();
  final _searchController = TextEditingController();

  List<ConversationPreview> _all = const [];
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
    final conversations = await _repository.loadConversations();
    if (!mounted) return;
    setState(() {
      _all = conversations;
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

  /// Instant local filtering — checks name only.
  List<ConversationPreview> get _filtered {
    if (_query.isEmpty) return _all;
    return _all.where((c) => c.name.toLowerCase().contains(_query)).toList();
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
                const ConnectionsHeader(),
                const SizedBox(height: 22),
                PremiumSearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const LoadingSkeleton()
                else if (!hasResults)
                  EmptyInbox(isSearch: isSearching)
                else ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
