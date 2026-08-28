import 'package:flutter/material.dart';

import '../../features/home_connection_dashboard_cards.dart';
import '../../features/profile/connections_view_model.dart';
import '../../features/profile/profile_navigation_mapper.dart';
import '../../features/profile/public_profile_screen.dart';
import '../../features/profile/supabase_profile_repository.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late final ConnectionsViewModel _viewModel = const ConnectionsViewModel();
  List<ConnectionUiModel> _requests = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _removing = <String>{};

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
      final incoming = await _viewModel.loadIncomingRequests();
      if (!mounted) return;
      setState(() {
        _requests = List.from(incoming)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  Future<void> _accept(ConnectionUiModel request) async {
    final result = await _viewModel.acceptRequest(request.connectionId);
    if (!mounted) return;
    if (result.isFailure) {
      _showError(result.error ?? 'Failed to accept request');
      return;
    }
    setState(() => _removing.add(request.connectionId));
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() {
      _removing.remove(request.connectionId);
      _requests.removeWhere((r) => r.connectionId == request.connectionId);
    });
  }

  Future<void> _decline(ConnectionUiModel request) async {
    final result = await _viewModel.rejectRequest(request.connectionId);
    if (!mounted) return;
    if (result.isFailure) {
      _showError(result.error ?? 'Failed to decline request');
      return;
    }
    setState(() => _removing.add(request.connectionId));
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() {
      _removing.remove(request.connectionId);
      _requests.removeWhere((r) => r.connectionId == request.connectionId);
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4D8D),
      ),
    );
  }

  Future<void> _openProfile(ConnectionUiModel request) async {
    final repository = const SupabaseProfileRepository();
    final profile = await repository.loadProfileByUserId(request.otherUserId);
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
                      'Connection Requests',
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
                      : _requests.isEmpty
                          ? _EmptyState(
                              icon: Icons.person_add_alt_1_outlined,
                              message:
                                  'No new requests. You\'re all caught up.',
                            )
                           : RefreshIndicator(
                               color: const Color(0xFF8B5CF6),
                               onRefresh: _load,
                               child: ListView(
                                 padding:
                                     const EdgeInsets.fromLTRB(20, 10, 20, 100),
                                 physics: const AlwaysScrollableScrollPhysics(),
                                 children: [
                                   for (final r in _requests)
                                     _RequestAnimatedRow(
                                       key: ValueKey<String>('request-${r.connectionId}'),
                                       request: r,
                                       removing: _removing.contains(r.connectionId),
                                       onViewProfile: () => _openProfile(r),
                                       onAccept: () => _accept(r),
                                       onDecline: () => _decline(r),
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

class _RequestAnimatedRow extends StatelessWidget {
  const _RequestAnimatedRow({
    super.key,
    required this.request,
    required this.removing,
    required this.onViewProfile,
    required this.onAccept,
    required this.onDecline,
  });

  final ConnectionUiModel request;
  final bool removing;
  final VoidCallback onViewProfile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
          child: _RequestRow(
            request: request,
            onViewProfile: onViewProfile,
            onAccept: onAccept,
            onDecline: onDecline,
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.onViewProfile,
    required this.onAccept,
    required this.onDecline,
  });

  final ConnectionUiModel request;
  final VoidCallback onViewProfile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
                    name: request.otherUserName,
                    color: request.otherUserColor ?? const Color(0xFFFF4D8D),
                    portrait: request.otherUserPortrait ?? '',
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
                        Text(
                          request.otherUserName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.otherUserBio ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: Color(0xFFB9C3DC),
                          ),
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
                    label: 'Accept Connection',
                    icon: Icons.check_rounded,
                    primary: true,
                    onTap: onAccept,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ActionPill(
                    label: 'Decline',
                    icon: Icons.close_rounded,
                    danger: true,
                    onTap: onDecline,
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
