import 'package:flutter/material.dart';

import '../../features/home_connection_dashboard_cards.dart';
import '../../features/profile/connections_view_model.dart';
import '../../features/profile/profile_navigation_mapper.dart';
import '../../features/profile/public_profile_screen.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key});

  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage> {
  late final ConnectionsViewModel _viewModel = const ConnectionsViewModel();
  List<ConnectionUiModel> _pending = const [];
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
      final outgoing = await _viewModel.loadOutgoingRequests();
      if (!mounted) return;
      setState(() {
        _pending = outgoing;
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

  Future<void> _cancel(ConnectionUiModel request) async {
    final result = await _viewModel.cancelRequest(request.connectionId);
    if (!mounted) return;
    if (result.isFailure) {
      _showError(result.error ?? 'Failed to cancel request');
      return;
    }
    setState(() => _removing.add(request.connectionId));
    await Future.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() {
      _removing.remove(request.connectionId);
      _pending.removeWhere((r) => r.connectionId == request.connectionId);
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

  void _openProfile(ConnectionUiModel request) {
    Navigator.of(context).push(
      premiumPublicProfileRoute(
        data: mapConnectionUiModelToProfile(request),
      ),
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
                      'Pending Requests',
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
                      : _pending.isEmpty
                          ? _EmptyState(
                              icon: Icons.hourglass_empty_rounded,
                              message: 'No pending requests.',
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 10, 20, 100),
                              itemCount: _pending.length,
                              itemBuilder: (context, index) {
                                final r = _pending[index];
                                final visible = !_removing.contains(r.connectionId);
                                return AnimatedSize(
                                  duration: const Duration(milliseconds: 360),
                                  curve: Curves.easeInOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: AnimatedOpacity(
                                    opacity: visible ? 1 : 0,
                                    duration: const Duration(milliseconds: 360),
                                    curve: Curves.easeInOutCubic,
                                    child: Padding(
                                      key: ValueKey<String>(
                                          'pending-${r.connectionId}'),
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _PendingRow(
                                        request: r,
                                        onViewProfile: () => _openProfile(r),
                                        onCancel: () => _cancel(r),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.request,
    required this.onViewProfile,
    required this.onCancel,
  });

  final ConnectionUiModel request;
  final VoidCallback onViewProfile;
  final VoidCallback onCancel;

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
                    color: request.otherUserColor ?? const Color(0xFFFFC24D),
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
                        Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                size: 13, color: Color(0xFFFFC24D)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Waiting for response',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFC24D),
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
            child: SizedBox(
              width: double.infinity,
              child: ActionPill(
                label: 'Cancel',
                icon: Icons.close_rounded,
                danger: true,
                onTap: onCancel,
              ),
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
