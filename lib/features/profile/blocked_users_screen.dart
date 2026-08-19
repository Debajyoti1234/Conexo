import 'package:flutter/material.dart';

import '../../app/theme/app_widgets.dart';
import '../home_discovery_animations.dart';
import 'safety_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _repository = const SafetyRepository();
  List<BlockedUser> _blocked = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repository.getBlockedUsers();
    if (!mounted) return;
    setState(() {
      _blocked = result.isSuccess ? result.value! : const [];
      _loading = false;
    });
  }

  Future<void> _unblock(BlockedUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2E),
        title: const Text('Unblock User', style: TextStyle(color: Color(0xFFEAEEF9))),
        content: Text(
          'Unblock ${user.blockedUserName}?',
          style: const TextStyle(color: Color(0xFFB9C3DC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await _repository.unblockUser(user.blockedUserId);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _blocked.removeWhere((u) => u.id == user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.blockedUserName} has been unblocked'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to unblock')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Blocked Users',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  )
                else if (_blocked.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 56,
                            color: const Color(0xFF8B5CF6).withValues(alpha: .35),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "You're not blocking anyone.",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB9C3DC),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Blocked users will appear here.',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFFB9C3DC).withValues(alpha: .7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._blocked.map(
                    (user) => EntranceFade(
                      child: _BlockedUserTile(
                        user: user,
                        onUnblock: () => _unblock(user),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.onUnblock,
  });

  final BlockedUser user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          _BlockedUserAvatar(
            name: user.blockedUserName,
            avatarUrl: user.blockedUserAvatar,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.blockedUserName,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEAEEF9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Blocked',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: const Color(0xFFE36D9D).withValues(alpha: .9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text(
              'Unblock',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserAvatar extends StatelessWidget {
  const _BlockedUserAvatar({
    required this.name,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: const Color(0xFF8B5CF6),
      );
    }
    return UserAvatar(name: name, size: 44);
  }
}
