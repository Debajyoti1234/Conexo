import 'package:flutter/material.dart';

import 'chat_models.dart';
import 'chat_repository.dart';
import 'chat_sections.dart';
import 'chat_widgets.dart';

/// The premium Connections inbox (Phase 6.1).
///
/// UI-only: loads demo conversations, supports instant local search, and
/// groups pinned vs recent. Tapping a conversation opens an in-file "Private
/// Chat" placeholder. No messaging, no Plans, no backend.
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
    Navigator.of(context).push(_privateChatPlaceholder(c));
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

/// The in-file "Private Chat" placeholder route — a premium fade + slide
/// transition into a centered message stating that messaging arrives in 6.2.
Route<void> _privateChatPlaceholder(ConversationPreview conversation) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _PrivateChatPlaceholder(conversation: conversation),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The placeholder screen shown when any conversation is tapped.
class _PrivateChatPlaceholder extends StatelessWidget {
  const _PrivateChatPlaceholder({required this.conversation});

  final ConversationPreview conversation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Private Chat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConversationAvatar(
                asset: conversation.avatarAsset,
                name: conversation.name,
                status: conversation.status,
                size: 88,
              ),
              const SizedBox(height: 24),
              Text(
                conversation.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: const Text(
                  'Private messaging will arrive in Phase 6.2.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFFB9C3DC),
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
