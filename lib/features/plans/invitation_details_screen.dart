import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

import '../../core/supabase/auth_service.dart';
import '../plans/plan_details_data.dart';
import '../plans/plan_details_screen.dart';
import '../plans/plan_repository.dart';
import '../plans/plans_data.dart';
import 'supabase_plan_repository.dart';

class InvitationDetailsScreen extends StatefulWidget {
  const InvitationDetailsScreen({
    required this.invitation,
    required this.repository,
    super.key,
  });

  final PlanInvitation invitation;
  final PlanRepository repository;

  @override
  State<InvitationDetailsScreen> createState() =>
      _InvitationDetailsScreenState();
}

class _InvitationDetailsScreenState extends State<InvitationDetailsScreen> {
  Experience? _plan;
  bool _loading = true;
  bool _accepting = false;
  bool _declining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    try {
      final repo = const SupabasePlanRepository();
      final plan = await repo.getPlanExperience(widget.invitation.planId);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load plan details';
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await widget.repository.acceptInvitation(widget.invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation accepted'),
          backgroundColor: Color(0xFF1F9D6B),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFD9485F),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept invitation. Please try again.'),
          backgroundColor: Color(0xFFD9485F),
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    try {
      await widget.repository.declineInvitation(widget.invitation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation declined'),
          backgroundColor: Color(0xFFD9485F),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFD9485F),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to decline invitation. Please try again.'),
          backgroundColor: Color(0xFFD9485F),
        ),
      );
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  void _openPlanDetails() {
    if (_plan == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanDetailsScreen(
          experience: _plan!,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inviterName = widget.invitation.inviterName?.trim().isNotEmpty ?? false
        ? widget.invitation.inviterName!.trim()
        : 'Someone';

    return Scaffold(
      backgroundColor: context.cxCanvas,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: context.cxInk),
                    )
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadPlan)
                      : _plan == null
                          ? const _EmptyState()
                          : _PlanPreview(
                              plan: _plan!,
                              inviterName: inviterName,
                              accepting: _accepting,
                              declining: _declining,
                              onAccept: _accept,
                              onDecline: _decline,
                              onTapPlan: _openPlanDetails,
                            ),
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
            icon: Icon(Icons.arrow_back_rounded, color: context.cxInk),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Text(
            'Invitation',
            style: TextStyle(
              fontSize: 22,
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w600,
              color: context.cxInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  const _PlanPreview({
    required this.plan,
    required this.inviterName,
    required this.accepting,
    required this.declining,
    required this.onAccept,
    required this.onDecline,
    required this.onTapPlan,
  });

  final Experience plan;
  final String inviterName;
  final bool accepting;
  final bool declining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTapPlan;

  @override
  Widget build(BuildContext context) {
    final e = plan;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onTapPlan,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: context.cxSurface,
                border: Border.all(
                  color: context.cxInk.withValues(alpha: .08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _InvitationCover(
                      asset: e.coverAsset,
                      accent: e.accent,
                      height: 180,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                            color: context.cxInk,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: context.cxInk,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Hosted by $inviterName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.cxSoft,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: context.cxInk,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${e.date} · ${e.time}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.cxSoft,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: context.cxInk,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.city,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.cxSoft,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (e.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            e.description,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: context.cxMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _ActionButtons(
            accepting: accepting,
            declining: declining,
            onAccept: onAccept,
            onDecline: onDecline,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// A self-contained, constraint-safe cover image for the invitation preview.
///
/// Unlike the discovery [PlanCover], this never uses `Stack(fit: StackFit.expand)`
/// — it renders a plain fixed-height [Image] with a gradient fallback, so it can
/// never assert on unbounded constraints when embedded in a scroll view / column.
class _InvitationCover extends StatelessWidget {
  const _InvitationCover({
    required this.asset,
    required this.accent,
    this.height = 180,
  });

  final String asset;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (asset.isEmpty) return _fallback();

    final isNetwork =
        asset.startsWith('http://') || asset.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        asset,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: double.infinity,
            color: accent.withValues(alpha: .25),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      asset,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, .25) ?? accent,
            accent,
            Color.lerp(accent, const Color(0xFFFFFFFF), .55) ?? accent,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event_rounded, size: 48, color: Colors.white),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.accepting,
    required this.declining,
    required this.onAccept,
    required this.onDecline,
  });

  final bool accepting;
  final bool declining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: declining ? null : onDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD9485F),
                side: const BorderSide(color: Color(0xFFD9485F)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: declining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD9485F),
                      ),
                    )
                  : const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 52,
child: FilledButton(
              onPressed: accepting ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: accepting
                    ? context.cxAccent.withValues(alpha: .5)
                    : context.cxAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: accepting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
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
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: context.cxMuted,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.cxSoft,
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
                    context.cxInk.withValues(alpha: .12),
                    context.cxInk.withValues(alpha: .04),
                  ],
                ),
                border: Border.all(
                  color: context.cxInk.withValues(alpha: .16),
                ),
              ),
              child: Icon(
                Icons.event_rounded,
                size: 42,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Plan unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: context.cxInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This plan may have been removed or is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.cxSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
