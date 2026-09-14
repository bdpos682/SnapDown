import 'media_info.dart';
import 'media_resolver.dart';
import '../platforms/direct/direct_resolver.dart';
import '../platforms/facebook/facebook_resolver.dart';
import '../platforms/instagram/instagram_resolver.dart';
import '../platforms/tiktok/tiktok_resolver.dart';
import '../platforms/twitter/twitter_resolver.dart';
import '../platforms/vimeo/vimeo_resolver.dart';
import '../platforms/youtube/youtube_resolver.dart';

class UnsupportedPlatformException implements Exception {
  final Uri url;
  const UnsupportedPlatformException(this.url);

  @override
  String toString() => 'Unsupported media platform for URL: $url';
}

class ResolverRegistry {
  static final ResolverRegistry _instance = ResolverRegistry._internal();
  factory ResolverRegistry() => _instance;

  final List<MediaResolver> _resolvers = [];

  ResolverRegistry._internal() {
    _registerDefaults();
  }

  void _registerDefaults() {
    _resolvers.addAll([
      YoutubeResolver(),
      TiktokResolver(),
      FacebookResolver(),
      InstagramResolver(),
      TwitterResolver(),
      VimeoResolver(),
      DirectResolver(),
    ]);
  }

  void registerResolver(MediaResolver resolver) {
    _resolvers.insert(0, resolver);
  }

  MediaResolver? findResolver(Uri url) {
    for (final resolver in _resolvers) {
      if (resolver.supports(url)) {
        return resolver;
      }
    }
    return null;
  }

  Future<MediaInfo> analyze(Uri url) async {
    final resolver = findResolver(url);
    if (resolver == null) {
      throw UnsupportedPlatformException(url);
    }
    return await resolver.analyze(url);
  }
}
