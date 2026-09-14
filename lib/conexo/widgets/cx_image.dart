import 'package:flutter/material.dart';

import '../../features/profile/profile_photo_resolver.dart';
import '../design/tokens.dart';

/// Shows a profile photo from a bundled asset, a URL, or a private storage
/// path (resolved to a signed URL). Fades in; falls back to a soft placeholder.
class CxImage extends StatefulWidget {
  const CxImage(
    this.path, {
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    super.key,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  State<CxImage> createState() => _CxImageState();
}

class _CxImageState extends State<CxImage> {
  ImageProvider? _provider;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CxImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  void _resolve() {
    final path = widget.path;
    _failed = false;
    if (path.isEmpty) {
      _provider = null;
      _failed = true;
      return;
    }
    if (path.startsWith('assets/')) {
      _provider = AssetImage(path);
      return;
    }
    if (path.startsWith('http')) {
      _provider = NetworkImage(path);
      return;
    }
    final cached = ProfilePhotoResolver.instance.getProvider(path);
    if (cached != null) {
      _provider = cached;
      return;
    }
    _provider = null;
    ProfilePhotoResolver.instance.resolvePhoto(path).then(
      (resolved) {
        if (mounted && widget.path == path) setState(() => _provider = resolved.imageProvider);
      },
      onError: (Object _) {
        if (mounted && widget.path == path) setState(() => _failed = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: c.surfaceAlt,
      alignment: Alignment.center,
      child: _failed ? Icon(Icons.person_rounded, color: c.inkMute) : null,
    );
    final provider = _provider;
    if (provider == null) return placeholder;
    return Image(
      image: provider,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          child: frame == null ? placeholder : child,
        );
      },
      errorBuilder: (_, _, _) => Container(
        width: widget.width,
        height: widget.height,
        color: c.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, color: c.inkMute),
      ),
    );
  }
}
