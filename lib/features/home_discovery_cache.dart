import 'package:flutter/widgets.dart';

class DiscoveryPhotoCache {
  static final Map<String, String> _signedUrlCache = {};
  static final Set<String> _prefetched = {};
  static final Set<String> _ready = {};
  static final Map<String, ImageProvider> _providerCache = {};

  static ImageProvider? getProvider(String remoteUrl) => _providerCache[remoteUrl];

  static String? getSignedUrl(String remoteUrl) => _signedUrlCache[remoteUrl];

  static void setSignedUrl(String remoteUrl, String? url) {
    if (url != null && url.isNotEmpty) {
      _signedUrlCache[remoteUrl] = url;
    }
  }

  static void setProvider(String remoteUrl, ImageProvider provider) {
    _providerCache[remoteUrl] = provider;
  }

  static bool isPrefetched(String profileId) => _prefetched.contains(profileId);

  static void markPrefetched(String profileId) => _prefetched.add(profileId);

  static bool isReady(String profileId) => _ready.contains(profileId);

  static void markReady(String profileId) => _ready.add(profileId);

  static void clear() {
    _signedUrlCache.clear();
    _providerCache.clear();
    _prefetched.clear();
    _ready.clear();
  }
}
