import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A lightweight, dependency-free GIF service that fetches from the Giphy API.
///
/// Uses the GIPHY_API_KEY dart-define (from [tool/supabase_dev.json]).
/// The [http] package is already a project dependency, so no new packages are introduced.
class GifService {
  GifService._();

  static final GifService instance = GifService._();

  static const String _baseUrl = 'api.giphy.com';
  static const String _apiKey = String.fromEnvironment('GIPHY_API_KEY');

  static const int defaultLimit = 20;

  /// A single GIF result from the Giphy API.
  final List<GifItem> _trendingCache = [];
  bool _trendingLoaded = false;

  /// Whether a valid API key was detected at compile time.
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Fetches trending GIFs. Caches the first page so the picker opens instantly
  /// on subsequent taps.
  Future<GifFetchResult> fetchTrending({int limit = defaultLimit}) async {
    debugPrint('GifService: fetchTrending started, hasApiKey=$hasApiKey, apiKeyLength=${_apiKey.length}');
    if (_apiKey.isEmpty) {
      debugPrint('GifService: GIPHY_API_KEY not configured — falling through to API (will get 401)');
    }
    if (_trendingLoaded && _trendingCache.isNotEmpty) {
      return GifFetchResult.success(List.unmodifiable(_trendingCache));
    }
    final result = await _fetchPageWithResult(
      path: '/v1/gifs/trending',
      query: '?api_key=$_apiKey&limit=$limit&rating=pg',
    );
    debugPrint('GifService: fetchTrending result items=${result.items.length}, isFailure=${result.isFailure}, error=${result.error}');
    if (result.isSuccess) {
      _trendingCache
        ..clear()
        ..addAll(result.items);
      _trendingLoaded = true;
    }
    return result;
  }

  /// Searches GIFs by [query].
  Future<GifFetchResult> search(String query, {int limit = defaultLimit}) async {
    debugPrint('GifService: search started, query=$query, hasApiKey=$hasApiKey');
    if (query.trim().isEmpty) return fetchTrending(limit: limit);

    final uriQuery = Uri.encodeComponent(query.trim());
    final result = await _fetchPageWithResult(
      path: '/v1/gifs/search',
      query: '?api_key=$_apiKey&q=$uriQuery&limit=$limit&rating=pg',
    );
    debugPrint('GifService: search result items=${result.items.length}, isFailure=${result.isFailure}, error=${result.error}');
    return result;
  }

  Future<GifFetchResult> _fetchPageWithResult({
    required String path,
    required String query,
  }) async {
    final uri = Uri.parse('https://$_baseUrl$path$query');
    debugPrint('GIF API request started: ${uri.host}$path');
    try {
      final response = await http.get(uri).timeout(
            const Duration(seconds: 12),
          );
      debugPrint('GIF API response: statusCode=${response.statusCode}, response length=${response.body.length}');
      if (response.statusCode != 200) {
        debugPrint('GIF API error status: ${response.statusCode}');
        debugPrint('GIF API error body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return GifFetchResult.failure(
          response.statusCode,
          'HTTP ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> raw = data['data'] as List<dynamic>? ?? [];
      debugPrint('GIF API parse: data count=${raw.length}');
      final items = raw
          .map((e) => GifItem.fromJson(e as Map<String, dynamic>))
          .whereType<GifItem>()
          .toList();
      debugPrint('GIF API parsed items: ${items.length}');
      return GifFetchResult.success(items);
    } catch (e, st) {
      debugPrint('GifService FAILED: $e');
      debugPrint('GifService stack: $st');
      return GifFetchResult.failure(-1, e.toString());
    }
  }

  void clearCache() {
    _trendingCache.clear();
    _trendingLoaded = false;
  }

  /// Returns cached trending GIFs (or empty if not yet loaded).
  List<GifItem> get cachedTrending =>
      List.unmodifiable(_trendingCache);

  /// Whether the trending cache is populated.
  bool get hasCachedTrending => _trendingLoaded && _trendingCache.isNotEmpty;
}

/// A single GIF from the Giphy API.
class GifItem {
  const GifItem({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
  });

  factory GifItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final original = images?['original'] as Map<String, dynamic>?;
    if (original == null) return _fallback(json);

    final url = original['url'] as String?;
    if (url == null || url.isEmpty) return _fallback(json);

    final width = int.tryParse(original['width'] as String? ?? '') ?? 0;
    final height = int.tryParse(original['height'] as String? ?? '') ?? 0;

    return GifItem(
      id: json['id'] as String? ?? '',
      url: url,
      width: width,
      height: height,
    );
  }

  static GifItem _fallback(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final shortCode = json['short_code'] as String? ?? id;
    final url = json['url'] as String? ?? '';
    return GifItem(
      id: shortCode,
      url: url,
      width: 0,
      height: 0,
    );
  }

  final String id;
  final String url;
  final int width;
  final int height;

  /// Approximate aspect ratio (width / height). Falls back to 1.0.
  double get aspectRatio => height > 0 ? width / height : 1.0;
}

/// Internal result type for GIF fetch operations, allowing the picker to
/// distinguish between an empty result (show "No GIFs found") and an actual
/// API/network error (show "Unable to load GIFs").
class GifFetchResult {
  const GifFetchResult._(this.items, this.error);

  const GifFetchResult.success(List<GifItem> items) : this._(items, null);

  const GifFetchResult.failure(int statusCode, String error)
      : this._(const [], error);

  final List<GifItem> items;
  final String? error;
  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}
