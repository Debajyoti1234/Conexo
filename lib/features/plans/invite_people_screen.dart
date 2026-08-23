import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/supabase/auth_service.dart';
import '../profile/connections_view_model.dart';
import '../profile/profile_photo_resolver.dart';
import 'plan_repository.dart';
import 'supabase_plan_repository.dart';

class InviteeOption {
  const InviteeOption({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.isVerified,
    this.age,
    this.isAlreadyMember = false,
    this.isAlreadyInvited = false,
    this.isRecentlyRemoved = false,
  });

  final String userId;
  final String name;
  final String photoUrl;
  final bool isVerified;
  final int? age;
  final bool isAlreadyMember;
  final bool isAlreadyInvited;
  final bool isRecentlyRemoved;

  InviteeOption copyWith({
    bool? selected,
  }) {
    return InviteeOption(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      isVerified: isVerified,
      age: age,
      isAlreadyMember: isAlreadyMember,
      isAlreadyInvited: isAlreadyInvited,
      isRecentlyRemoved: isRecentlyRemoved,
    );
  }
}

class InvitePeopleScreen extends StatefulWidget {
  const InvitePeopleScreen({
    required this.planId,
    required this.planTitle,
    this.repository = const SupabasePlanRepository(),
    super.key,
  });

  final String planId;
  final String planTitle;
  final PlanRepository repository;

  @override
  State<InvitePeopleScreen> createState() => _InvitePeopleScreenState();
}

class _InvitePeopleScreenState extends State<InvitePeopleScreen> {
  final ConnectionsViewModel _connectionsViewModel = const ConnectionsViewModel();
  final Set<String> _selected = <String>{};
  List<InviteeOption> _invitees = const [];
  bool _loading = true;
  bool _sending = false;
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
      final connections = await _connectionsViewModel.loadAcceptedConnections();
      final existingMembers = await widget.repository.getPlanMembers(widget.planId);
      final existingInvites = await widget.repository.getSentInvitations(widget.planId);

      // Resolve real profile photos through the canonical private
      // profile-photos + signed-URL pipeline (the same one Plan Members uses).
      // ConnectionsViewModel.otherUserPortrait only carries the local
      // `assetPath`, which is absent for uploaded photos, so we resolve the
      // primary photo's signed URL by user id here.
      final connectionIds = [for (final c in connections) c.otherUserId];
      final photoUrls = await widget.repository.getProfilePhotoUrls(connectionIds);

      final currentMemberIds = <String>{};
      final removedMemberIds = <String>{};
      for (final m in existingMembers) {
        if (m.status == 'joined') {
          currentMemberIds.add(m.userId);
        } else if (m.status == 'removed' || m.status == 'left') {
          removedMemberIds.add(m.userId);
        }
      }

      final invitedIds = <String>{
        for (final i in existingInvites) i.inviteeId,
      };

      final invitees = connections.map((c) {
        // Prefer the resolved signed URL; fall back to any local asset the
        // connection model already carries.
        final resolvedPhoto = photoUrls[c.otherUserId] ??
            (c.otherUserPortrait ?? '');
        return InviteeOption(
          userId: c.otherUserId,
          name: c.otherUserName,
          photoUrl: resolvedPhoto,
          isVerified: c.isVerified,
          age: c.otherUserAge,
          isAlreadyMember: currentMemberIds.contains(c.otherUserId),
          isAlreadyInvited: invitedIds.contains(c.otherUserId),
          isRecentlyRemoved: removedMemberIds.contains(c.otherUserId),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _invitees = invitees;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load connections';
      });
    }
  }

  Future<void> _sendInvitations() async {
    if (_selected.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final futures = _selected.map((userId) {
        return widget.repository.inviteToPlan(widget.planId, userId);
      }).toList();

      await Future.wait(futures);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected.length == 1
                ? 'Invitation sent'
                : '${_selected.length} invitations sent',
          ),
          backgroundColor: const Color(0xFF47D7A5),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFFF4D8D),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send invitations. Please try again.'),
          backgroundColor: Color(0xFFFF4D8D),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : _invitees.isEmpty
                          ? const _EmptyState()
                          : _InviteeList(
                              invitees: _invitees,
                              selected: _selected,
                              onToggle: (userId) {
                                setState(() {
                                  if (_selected.contains(userId)) {
                                    _selected.remove(userId);
                                  } else {
                                    _selected.add(userId);
                                  }
                                });
                              },
                            ),
            ),
            _Footer(
              sending: _sending,
              selectedCount: _selected.length,
              onSend: _sendInvitations,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Close',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Invite People',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEAEEF9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteeList extends StatelessWidget {
  const _InviteeList({
    required this.invitees,
    required this.selected,
    required this.onToggle,
  });

  final List<InviteeOption> invitees;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: invitees.length,
      itemBuilder: (context, index) {
        final invitee = invitees[index];
        final isSelected = selected.contains(invitee.userId);
        final isDisabled = invitee.isAlreadyMember || invitee.isAlreadyInvited;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: isDisabled ? null : () => onToggle(invitee.userId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF182039).withValues(alpha: .78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6).withValues(alpha: .6)
                      : Colors.white.withValues(alpha: .06),
                ),
              ),
              child: Row(
                children: [
                  _InviteeAvatar(
                    photoUrl: invitee.photoUrl,
                    name: invitee.name,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                invitee.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEAEEF9),
                                ),
                              ),
                            ),
                            if (invitee.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invitee.isAlreadyMember
                              ? 'Already joined'
                              : invitee.isAlreadyInvited
                                  ? 'Invitation pending'
                                  : invitee.isRecentlyRemoved
                                      ? 'Recently removed'
                                      : _subtitleForAge(invitee.age),
                          style: TextStyle(
                            fontSize: 12,
                            color: invitee.isAlreadyMember || invitee.isAlreadyInvited
                                ? const Color(0xFF8A96B4)
                                : const Color(0xFFAEB9D6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDisabled)
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF8A96B4),
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _subtitleForAge(int? age) {
    if (age == null) return 'Connection';
    return '$age · Connection';
  }
}

class _InviteeAvatar extends StatefulWidget {
  const _InviteeAvatar({
    required this.photoUrl,
    required this.name,
  });

  final String photoUrl;
  final String name;

  @override
  State<_InviteeAvatar> createState() => _InviteeAvatarState();
}

class _InviteeAvatarState extends State<_InviteeAvatar> {
  String? _signedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.photoUrl.startsWith('profiles/')) {
      _resolveSignedUrl();
    }
  }

  Future<void> _resolveSignedUrl() async {
    try {
      final resolved = await ProfilePhotoResolver.instance.resolvePhoto(
        widget.photoUrl,
      );
      if (!mounted) return;
      setState(() => _signedUrl = resolved.signedUrl);
    } catch (_) {
      // keep fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _signedUrl ?? widget.photoUrl;
    final isNetwork = resolvedUrl.startsWith('http');

    if (resolvedUrl.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF8B5CF6).withValues(alpha: .2),
        ),
        child: Center(
          child: Text(
            widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ),
      );
    }

    if (resolvedUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: AssetImage(resolvedUrl),
        child: widget.name.isEmpty
            ? null
            : Center(
                child: Text(
                  widget.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundImage: isNetwork ? NetworkImage(resolvedUrl) : null,
      onBackgroundImageError: isNetwork
          ? (Object exception, StackTrace? stackTrace) {}
          : null,
      child: !isNetwork
          ? Center(
              child: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            )
          : null,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.sending,
    required this.selectedCount,
    required this.onSend,
  });

  final bool sending;
  final int selectedCount;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0 && !sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onSend : null,
          style: FilledButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF8B5CF6).withValues(alpha: .25),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  selectedCount == 0
                      ? 'Send Invitations'
                      : 'Send Invitations ($selectedCount)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFF9DB2E8),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFFB9C3DC),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .12),
                    Colors.white.withValues(alpha: .04),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .16),
                ),
              ),
              child: const Icon(
                Icons.people_rounded,
                size: 42,
                color: Color(0xFFB7A5FF),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No connections to invite',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Color(0xFFEAEEF9),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Connect with people first, then invite them to your plans.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFFAEB9D6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
