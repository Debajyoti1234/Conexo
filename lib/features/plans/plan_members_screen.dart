import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'plan_repository.dart';
import 'plan_details_data.dart';
import 'plan_details_widgets.dart';
import 'supabase_plan_repository.dart';
import '../profile/profile_navigation_mapper.dart';
import '../profile/public_profile_screen.dart';

class PlanMembersScreen extends StatefulWidget {
  const PlanMembersScreen({required this.planId, super.key});

  final String planId;

  @override
  State<PlanMembersScreen> createState() => _PlanMembersScreenState();
}

class _PlanMembersScreenState extends State<PlanMembersScreen> {
  final PlanRepository _repo = const SupabasePlanRepository();
  List<PlanMembership> _members = const [];
  String? _planTitle;
  bool _isCreator = false;
  bool _loading = true;
  String? _error;

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
      final members = await _repo.getPlanMembers(widget.planId);
      final currentUserId = AuthService.currentUser?.id ?? '';
      final joined = members.where((m) => m.status == 'joined').toList();

      String? title;
      bool isCreator = false;
      try {
        final client = Supabase.instance.client;
        final planRow = await client
            .from('plans')
            .select('title, creator_id')
            .eq('id', widget.planId)
            .maybeSingle();

        if (planRow != null) {
          final rawTitle = (planRow['title'] as String?)?.trim();
          title = (rawTitle == null || rawTitle.isEmpty) ? 'Plan' : rawTitle;
          final creatorId = planRow['creator_id'] as String?;
          isCreator = creatorId != null && creatorId == currentUserId;
        }
      } catch (_) {
        // keep nulls on failure
      }

      if (!mounted) return;
      setState(() {
        _members = joined;
        _planTitle = title;
        _isCreator = isCreator;
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

  Future<void> _removeMember(PlanMembership member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2E),
        title: const Text('Remove Member', style: TextStyle(color: Color(0xFFEAEEF9))),
        content: Text(
          'Remove ${member.displayName?.trim().isNotEmpty ?? false ? member.displayName!.trim() : 'this member'} from the plan?',
          style: const TextStyle(color: Color(0xFFB9C3DC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D8D)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _repo.removePlanMember(widget.planId, member.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    }
  }

  void _viewMember(PlanMembership member) {
    final name = member.displayName?.trim().isNotEmpty ?? false
        ? member.displayName!.trim()
        : 'User ${member.userId.substring(0, 8)}';
    Navigator.of(context).push(
      premiumPublicProfileRoute(
        data: mapPlanParticipantToProfile(
          userId: member.userId,
          name: name,
          photoUrl: member.photoUrl ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020).withValues(alpha: .92),
        title: Text(
          _planTitle ?? 'Members',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFFF4D8D)),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFFB9C3DC)),
                        ),
                      ],
                    ),
                  ),
                )
              : _members.isEmpty
                  ? Center(
                      child: Text(
                        'No members yet',
                        style: const TextStyle(fontSize: 15, color: Color(0xFF9DB2E8)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isHost = member.role == 'creator';
                        final currentUserId = AuthService.currentUser?.id ?? '';
                        final isMe = member.userId == currentUserId;
                        final canRemove = _isCreator && !isHost && !isMe;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: .06)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                              leading: ParticipantAvatar(
                                asset: member.photoUrl ?? '',
                                accent: const Color(0xFF8B5CF6),
                                label: member.displayName?.trim().isNotEmpty ?? false
                                    ? member.displayName!.trim()
                                    : '?',
                                isHost: isHost,
                              ),
                              title: Text(
                                member.displayName?.trim().isNotEmpty ?? false
                                    ? member.displayName!.trim()
                                    : 'User ${member.userId.substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                isHost
                                    ? 'Host'
                                    : isMe
                                        ? 'You'
                                        : 'Member',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF9DB2E8),
                                ),
                              ),
                              trailing: canRemove
                                  ? IconButton(
                                      onPressed: () => _removeMember(member),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFFFF6B6B),
                                      ),
                                      tooltip: 'Remove',
                                    )
                                  : isHost
                                      ? Icon(
                                          Icons.star_rounded,
                                          color: const Color(0xFFFFC24D),
                                          size: 20,
                                        )
                                      : null,
                              onTap: () => _viewMember(member),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
