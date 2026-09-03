import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/chat/chat_repository.dart';
import '../../features/chat/chat_models.dart';
import '../../features/chat/conversation_screen.dart';
import '../../features/home_connection_dashboard_cards.dart';
import '../../features/profile/connections_view_model.dart';
import '../../features/profile/profile_navigation_mapper.dart';
import '../../features/profile/public_profile_screen.dart';
import '../../features/profile/supabase_profile_repository.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  late final ConnectionsViewModel _viewModel = const ConnectionsViewModel();
  List<ConnectionUiModel> _connections = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _removing = <String>{};
  final ChatRepository _chatRepository = const ChatRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accepted = await _viewModel.loadAcceptedConnections();
      if (!mounted) return;
      setState(() {
        _connections = List.from(accepted)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(ConnectionUiModel connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141C31),
        title: const Text('Remove connection?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${connection.otherUserName} from your network?',
          style: const TextStyle(color: Color(0xFFB9C3DC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Remove', style: TextStyle(color: Color(0xFFE36D9D))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removing.add(connection.connectionId));
    final result = await _viewModel.removeConnection(connection.connectionId);
    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _removing.remove(connection.connectionId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to remove connection'),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
      return;
    }
    setState(() {
      _removing.remove(connection.connectionId);
      _connections.removeWhere((c) => c.connectionId == connection.connectionId);
    });
  }

  Future<void> _openProfile(ConnectionUiModel connection) async {
    final repository = const SupabaseProfileRepository();
    final profile = await repository.loadProfileByUserId(connection.otherUserId);
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not found')),
      );
      return;
    }
    Navigator.of(context).push(
      premiumPublicProfileRoute(data: mapUserProfileToPublicProfile(profile)),
    );
  }

  Future<void> _openRoom(ConnectionUiModel connection) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result =
        await _chatRepository.getOrCreateConnectionConversation(
      connection.connectionId,
    );
    if (!mounted) return;
    if (result.isFailure) {
      scaffoldMessenger.showSnackBar(
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

    final preview = ConversationPreview(
      id: conversationId,
      name: connection.otherUserName,
      avatarAsset: connection.otherUserPortrait ?? '',
      lastMessage: '',
      timestamp: '',
      type: ConversationType.private,
      status: ConversationStatus.recentlyConnected,
      lastMessageType: LastMessageType.connectionAccepted,
      unreadCount: unreadCount,
      isVerified: connection.isVerified,
    );

    navigator.push(
      conversationRoute(preview, chatRepository: _chatRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your Network',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEAEEF9),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _connections.isEmpty
                          ? _EmptyState(
                              icon: Icons.group_add_outlined,
                              message:
                                  'Your network is just getting started.',
                            )
                           : RefreshIndicator(
                               color: const Color(0xFF8B5CF6),
                               onRefresh: _load,
                               child: ListView(
                                 padding:
                                     const EdgeInsets.fromLTRB(20, 10, 20, 100),
                                 physics: const AlwaysScrollableScrollPhysics(),
                                 children: [
                                   for (final c in _connections)
                                     _NetworkAnimatedRow(
                                       key: ValueKey<String>('network-${c.connectionId}'),
                                       connection: c,
                                       removing: _removing.contains(c.connectionId),
                                       onViewProfile: () => _openProfile(c),
                                       onOpenRoom: () => _openRoom(c),
                                       onRemove: () => _remove(c),
                                     ),
                                 ],
                               ),
                             ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkAnimatedRow extends StatelessWidget {
  const _NetworkAnimatedRow({
    super.key,
    required this.connection,
    required this.removing,
    required this.onViewProfile,
    required this.onOpenRoom,
    required this.onRemove,
  });

  final ConnectionUiModel connection;
  final bool removing;
  final VoidCallback onViewProfile;
  final VoidCallback onOpenRoom;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: removing ? 0 : 1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        child: Padding(
          padding: EdgeInsets.only(bottom: removing ? 0 : 12),
          child: _NetworkRow(
            connection: connection,
            onViewProfile: onViewProfile,
            onOpenRoom: onOpenRoom,
            onRemove: onRemove,
          ),
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.connection,
    required this.onViewProfile,
    required this.onOpenRoom,
    required this.onRemove,
  });

  final ConnectionUiModel connection;
  final VoidCallback onViewProfile;
  final VoidCallback onOpenRoom;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141C31).withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InkWell(
                  onTap: onViewProfile,
                  borderRadius: BorderRadius.circular(28),
                  child: PortraitAvatar(
                    name: connection.otherUserName,
                    color: connection.otherUserColor ?? const Color(0xFF8B5CF6),
                    portrait: connection.otherUserPortrait ?? '',
                    size: 52,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: onViewProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    connection.otherUserName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (connection.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded,
                                        size: 15, color: Color(0xFF77DFF1)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${connection.otherUserAge ?? 0} • ${connection.otherUserOccupation ?? ''}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB9C3DC),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: Color(0xFF9DB2E8)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                connection.otherUserCity ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9DB2E8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: ActionPill(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: onOpenRoom,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ActionPill(
                    label: 'Remove',
                    icon: Icons.close_rounded,
                    danger: true,
                    onTap: onRemove,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4D8D).withValues(alpha: .12),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 27, color: Color(0xFFFF4D8D)),
          ),
          const SizedBox(height: 14),
          Text(
            'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFB9C3DC),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: .14),
              ),
              child: Icon(icon, size: 27, color: const Color(0xFFB7A5FF)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB9C3DC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
