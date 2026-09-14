import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/data_source.dart';
import '../../data/mock_data.dart';
import '../../design/routes.dart';
import '../../design/tokens.dart';
import '../../design/widgets.dart';
import '../../widgets/cx_image.dart';
import '../../widgets/profile_view.dart';
import '../auth/auth_scaffold.dart' show showCxSnack;
import '../match/match_screen.dart';
import '../profile/edit_profile_screen.dart';

String _likeLabel(Like like) => switch (like.target) {
  LikeTarget.prompt => 'Liked your prompt',
  LikeTarget.photo => 'Liked your photo',
  LikeTarget.profile => 'Likes your profile',
};

class LikesScreen extends StatelessWidget {
  const LikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final likes = s.likesYou;

    final Widget content;
    if (likes.isEmpty && s.loadingLikes) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6, color: c.violet)),
        ),
      );
    } else if (likes.isEmpty && s.likesError != null) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Likes didn\'t load',
            body: s.likesError!,
            action: 'Try again',
            onAction: s.refreshLikes,
          ),
        ),
      );
    } else if (likes.isEmpty) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: EmptyState(
            icon: Icons.favorite_rounded,
            title: 'No likes yet',
            body: 'Profiles with three prompts get noticed a lot more. Just saying.',
            action: 'Polish my profile',
            onAction: () => Navigator.of(context).push(cxRoute(const EditProfileScreen())),
          ),
        ),
      );
    } else {
      content = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .66,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => Reveal(index: i, child: _LikeCard(likes[i])),
            childCount: likes.length,
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: c.violet,
        backgroundColor: c.surface,
        onRefresh: s.refreshLikes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ScreenTitle(
                title: 'Likes you',
                subtitle: likes.isEmpty
                    ? 'Nothing yet — good things take a minute.'
                    : likes.length == 1
                    ? 'Someone\'s into you. Your move.'
                    : '${likes.length} people are into you. Your move.',
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}

class _LikeCard extends StatelessWidget {
  const _LikeCard(this.like);
  final Like like;

  @override
  Widget build(BuildContext context) {
    final p = like.from;
    return Pressable(
      scale: .97,
      onTap: () => Navigator.of(context).push(cxRoute(LikeDetailScreen(like: like))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CxImage(p.firstPhoto),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC120C26)],
                  stops: [.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (like.comment != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        like.comment!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ConexoType.body(const Color(0xFF1A1433), size: 12.5, w: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    p.age > 0 ? '${p.name}, ${p.age}' : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ConexoType.title(Colors.white, size: 21),
                  ),
                  const SizedBox(height: 2),
                  Text(_likeLabel(like), style: ConexoType.label(Colors.white.withValues(alpha: .8), size: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LikeDetailScreen extends StatefulWidget {
  const LikeDetailScreen({required this.like, super.key});
  final Like like;

  @override
  State<LikeDetailScreen> createState() => _LikeDetailScreenState();
}

class _LikeDetailScreenState extends State<LikeDetailScreen> {
  bool _busy = false;

  Future<void> _match() async {
    setState(() => _busy = true);
    try {
      final m = await ConexoScope.read(context).acceptLike(widget.like);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(cxRoute(MatchScreen(match: m), fullscreen: true));
    } on ConexoFailure catch (e) {
      if (mounted) showCxSnack(context, e.message);
    } catch (_) {
      if (mounted) showCxSnack(context, 'That didn\'t go through. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final s = ConexoScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await s.dismissLike(widget.like);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t remove that like. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final s = ConexoScope.of(context);
    final p = widget.like.from;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  CxIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ProfileView(person: p, header: _LikedBanner(like: widget.like, me: s.profile)),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.paddingOf(context).bottom + 20,
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Remove',
                          child: Pressable(
                            onTap: _busy ? null : _remove,
                            scale: .88,
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: c.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.line),
                                boxShadow: c.softShadow,
                              ),
                              child: Icon(Icons.close_rounded, color: c.ink, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CxButton(
                            label: 'Match with ${p.name}',
                            icon: Icons.favorite_rounded,
                            height: 58,
                            loading: _busy,
                            onTap: _match,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikedBanner extends StatelessWidget {
  const _LikedBanner({required this.like, required this.me});
  final Like like;
  final Person me;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final prompt = me.prompts.where((p) => p.question == like.targetLabel).firstOrNull;
    return CxCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => c.warm.createShader(r),
                child: const Icon(Icons.favorite_rounded, size: 18),
              ),
              const SizedBox(width: 8),
              Text(_likeLabel(like), style: ConexoType.label(c.inkSoft, size: 13)),
            ],
          ),
          if (like.target == LikeTarget.profile) ...[
            const SizedBox(height: 6),
            Text('Match to start chatting.', style: ConexoType.body(c.inkMute, size: 13)),
          ] else ...[
            const SizedBox(height: 12),
            if (prompt != null)
              PromptPreview(prompt)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CxImage(me.firstPhoto, height: 120, width: 96),
              ),
          ],
          if (like.comment != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: c.warm,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Text(like.comment!, style: ConexoType.body(Colors.white, size: 15, w: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
