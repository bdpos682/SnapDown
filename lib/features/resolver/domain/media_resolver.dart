import 'media_info.dart';
import 'media_format.dart';

abstract class MediaResolver {
  /// Returns whether this resolver can handle the specified URL
  bool supports(Uri url);

  /// Analyzes the URL and extracts metadata, thumbnails, duration, and formats
  Future<MediaInfo> analyze(Uri url);

  /// Gets available media formats and transient stream URLs for the specified URL
  Future<List<MediaFormat>> getFormats(Uri url);
}
