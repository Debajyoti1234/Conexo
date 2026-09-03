import 'dart:async';

import 'package:flutter/material.dart';

import 'gif_service.dart';

/// Inline GIF tray that renders directly above the composer.
///
/// Reuses [GifService] for fetching. Presents trending GIFs by default,
/// search results while typing, and loading/error/empty states.
/// Selection is reported via [onGifSelected].
class GifTray extends StatefulWidget {
  const GifTray({
    required this.onGifSelected,
    this.searchQuery = '',
    this.onRetry,
    super.key,
  });

  final ValueChanged<GifItem> onGifSelected;
  final String searchQuery;
  final VoidCallback? onRetry;

  @override
  State<GifTray> createState() => _GifTrayState();
}

class _GifTrayState extends State<GifTray> {
  final List<GifItem> _items = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void didUpdateWidget(covariant GifTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _doSearch(widget.searchQuery);
    }
  }

  @override
  void dispose() {
    GifService.instance.clearCache();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    debugPrint('GifTray: _loadTrending, hasApiKey=${GifService.instance.hasApiKey}');
    final result = await GifService.instance.fetchTrending();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result.items);
      _loading = false;
      _searching = false;
      if (result.isFailure) {
        if (!GifService.instance.hasApiKey) {
          _error = 'GIPHY API key not configured';
        } else {
          _error = 'Unable to load GIFs';
        }
      } else if (result.items.isEmpty) {
        _error = 'No GIFs found';
      } else {
        _error = null;
      }
    });
  }

  Future<void> _doSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _items
          ..clear()
          ..addAll(GifService.instance.cachedTrending);
        _searching = false;
        if (GifService.instance.hasCachedTrending && _items.isNotEmpty) {
          _error = null;
        } else {
          _error = 'No GIFs found';
        }
      });
      return;
    }

    setState(() => _searching = true);
    final result = await GifService.instance.search(trimmed);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result.items);
      _searching = false;
      _loading = false;
      if (result.isFailure) {
        _error = 'Unable to load GIFs';
      } else if (result.items.isEmpty) {
        _error = 'No GIFs found';
      } else {
        _error = null;
      }
    });
  }

  Future<void> _onRetry() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
    });
    await _loadTrending();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          _buildContent(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return _buildLoadingGrid();
    }
    if (_error != null && _items.isEmpty) {
      return _buildError();
    }
    return _buildGrid();
  }

  Widget _buildLoadingGrid() {
    const rowCount = 3;
    const colCount = 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colCount,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.4,
        ),
        itemCount: rowCount * colCount,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 32,
              color: Colors.white.withValues(alpha: .3),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: .5),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFF8B5CF6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_items.isEmpty && !_searching) {
      return _buildError();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.4,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final gif = _items[index];
          return _GifTile(
            gif: gif,
            onTap: () => widget.onGifSelected(gif),
          );
        },
      ),
    );
  }
}

/// A single GIF tile in the tray grid.
class _GifTile extends StatelessWidget {
  const _GifTile({required this.gif, required this.onTap});

  final GifItem gif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withValues(alpha: .10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              gif.url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  size: 20,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
