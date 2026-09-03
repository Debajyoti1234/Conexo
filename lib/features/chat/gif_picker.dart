import 'dart:async';

import 'package:flutter/material.dart';

import 'gif_service.dart';

/// A premium, lightweight GIF picker presented as a bottom sheet.
///
/// Supports browsing trending GIFs, searching, selecting a GIF, and
/// canceling. The selected [GifItem] is returned via `Navigator.pop`.
/// Designed to feel like a modern messaging app — compact, glassy, and
/// focused on the content.
class GifPicker extends StatefulWidget {
  const GifPicker({super.key});

  @override
  State<GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends State<GifPicker> {
  final _searchController = TextEditingController();
  final List<GifItem> _items = [];
  bool _loading = true;
  bool _searching = false;
  String _currentQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    GifService.instance.clearCache();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    debugPrint('GifPicker: _loadTrending, hasApiKey=${GifService.instance.hasApiKey}');
    final result = await GifService.instance.fetchTrending();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result.items);
      _loading = false;
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

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query == _currentQuery) return;
    _currentQuery = query;
    _searchIfNeeded();
  }

  // Debounce search by 400ms to avoid hammering the API.
  void _searchIfNeeded() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _doSearch);
  }

  Timer? _searchDebounce;

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
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
    final result = await GifService.instance.search(query);
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result.items);
      _searching = false;
      if (result.isFailure) {
        _error = 'Unable to load GIFs';
      } else if (result.items.isEmpty) {
        _error = 'No GIFs found';
      } else {
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.56,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .42),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _searchController.text.trim().isNotEmpty
                          ? 'Search results'
                          : 'Trending GIFs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEAEEF9),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Color(0xFFB9C3DC),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 8),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search GIFs...',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF9DB2E8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: Color(0xFF9DB2E8),
          ),
          isCollapsed: true,
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: .05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        cursorColor: const Color(0xFFB7A5FF),
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
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.4,
        ),
        itemCount: rowCount * colCount,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Expanded(
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
            if (_error != null && _error != 'No GIFs found')
              ...[
                const SizedBox(height: 8),
                Text(
                  'GIPHY API key detected: ${GifService.instance.hasApiKey}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .35),
                  ),
                ),
              ],
            const SizedBox(height: 14),
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

  Future<void> _onRetry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadTrending();
  }

  Widget _buildGrid() {
    if (_items.isEmpty && !_searching) {
      return _buildError();
    }
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.4,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final gif = _items[index];
          return _GifTile(
            gif: gif,
            onTap: () => Navigator.of(context).pop(gif),
          );
        },
      ),
    );
  }
}

/// A single GIF tile in the picker grid. Shows a thumbnail with a subtle
/// hover/press overlay.
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
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withValues(alpha: .10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
