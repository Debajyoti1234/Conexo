import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_widgets.dart';
import '../plans/plans_theme.dart';
import '../plans/plan_details_widgets.dart';
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.cxSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.cxLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unblock User',
                style: plansDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.cxInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unblock ${user.blockedUserName}?',
                style: plansBody(
                  color: context.cxSoft,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: context.cxSoft,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.cxAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Unblock'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      backgroundColor: context.cxCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Row(
                  children: [
                    CircleGlassButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                      semanticLabel: 'Back',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Blocked Users',
                      style: plansDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.cxInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_loading)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: context.cxInk),
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
                            color: context.cxInk.withValues(alpha: .35),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "You're not blocking anyone.",
                            style: plansBody(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.cxSoft,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Blocked users will appear here.',
                            style: plansBody(
                              fontSize: 13,
                              color: context.cxSoft.withValues(alpha: .7),
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
        color: context.cxGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.cxLine),
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
                  style: plansBody(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: context.cxInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Blocked',
                  style: plansBody(
                    fontSize: 12.5,
                    color: context.cxDanger.withValues(alpha: .9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              foregroundColor: context.cxAccent,
            ),
            child: Text(
              'Unblock',
              style: plansBody(
                fontWeight: FontWeight.w700,
                color: context.cxAccent,
              ),
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
        backgroundColor: context.cxAccent,
      );
    }
    return UserAvatar(name: name, size: 44);
  }
}
