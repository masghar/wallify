/// Which API a wallpaper came from.
enum WallpaperSource { unsplash, pexels }

extension WallpaperSourceLabel on WallpaperSource {
  String get label => switch (this) {
        WallpaperSource.unsplash => 'Unsplash',
        WallpaperSource.pexels => 'Pexels',
      };
}

/// A single wallpaper photo, normalized across Unsplash and Pexels.
class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.source,
    required this.thumbUrl,
    required this.fullUrl,
    String? previewUrl,
    required this.photographer,
    required this.photographerUrl,
    required this.pageUrl,
    this.downloadLocation,
    this.avgColor,
    this.width,
    this.height,
  }) : previewUrl = previewUrl ?? fullUrl;

  /// Unique across sources, e.g. `unsplash:AbC123`.
  final String id;
  final WallpaperSource source;

  /// Small image for grid tiles.
  final String thumbUrl;

  /// Original high-resolution image URL.
  final String fullUrl;

  /// Screen-friendly image (~1080–1880w) for the detail preview. Falls back
  /// to [fullUrl] when the API gave no medium rendition.
  final String previewUrl;

  /// CDN-resized download URL. Both Unsplash (imgix) and Pexels support
  /// on-the-fly resizing via query parameters, so asking for ~wallpaper size
  /// instead of the 20 MB original makes downloads several times faster
  /// without visible quality loss on device screens.
  String downloadUrl({int targetWidth = 2880}) {
    final uri = Uri.tryParse(fullUrl);
    if (uri == null) return fullUrl;
    final params = Map<String, String>.from(uri.queryParameters);
    switch (source) {
      case WallpaperSource.unsplash:
        params['w'] = '$targetWidth';
        params['fit'] = 'max';
        params['q'] = '85';
        params['fm'] = 'jpg';
      case WallpaperSource.pexels:
        params['auto'] = 'compress';
        params['cs'] = 'tinysrgb';
        params['w'] = '$targetWidth';
    }
    return uri.replace(queryParameters: params).toString();
  }

  final String photographer;
  final String photographerUrl;

  /// Web page of the photo (for attribution links).
  final String pageUrl;

  /// Unsplash only: endpoint that must be pinged when the photo is downloaded
  /// (required by the Unsplash API guidelines).
  final String? downloadLocation;

  /// Hex color like `#1A2B3C`, used as a placeholder while loading.
  final String? avgColor;

  final int? width;
  final int? height;

  double get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : 0.7;

  factory Wallpaper.fromUnsplashJson(Map<String, dynamic> json) {
    final urls = (json['urls'] as Map<String, dynamic>?) ?? const {};
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    final userLinks = (user['links'] as Map<String, dynamic>?) ?? const {};
    final links = (json['links'] as Map<String, dynamic>?) ?? const {};
    return Wallpaper(
      id: 'unsplash:${json['id']}',
      source: WallpaperSource.unsplash,
      thumbUrl: (urls['small'] ?? urls['regular'] ?? '') as String,
      fullUrl: (urls['full'] ?? urls['raw'] ?? urls['regular'] ?? '') as String,
      previewUrl: urls['regular'] as String?,
      photographer: (user['name'] ?? 'Unknown') as String,
      photographerUrl: (userLinks['html'] ?? '') as String,
      pageUrl: (links['html'] ?? '') as String,
      downloadLocation: links['download_location'] as String?,
      avgColor: json['color'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  factory Wallpaper.fromPexelsJson(Map<String, dynamic> json) {
    final src = (json['src'] as Map<String, dynamic>?) ?? const {};
    return Wallpaper(
      id: 'pexels:${json['id']}',
      source: WallpaperSource.pexels,
      thumbUrl: (src['medium'] ?? src['large'] ?? '') as String,
      fullUrl: (src['original'] ?? src['large2x'] ?? '') as String,
      previewUrl: (src['large2x'] ?? src['large']) as String?,
      photographer: (json['photographer'] ?? 'Unknown') as String,
      photographerUrl: (json['photographer_url'] ?? '') as String,
      pageUrl: (json['url'] ?? '') as String,
      avgColor: json['avg_color'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, Object?> toDbMap(
      {String? filePath, String? category, int? createdAtMillis}) => {
        'id': id,
        'source': source.name,
        'thumb_url': thumbUrl,
        'full_url': fullUrl,
        'photographer': photographer,
        'photographer_url': photographerUrl,
        'page_url': pageUrl,
        'avg_color': avgColor,
        'width': width,
        'height': height,
        'file_path': filePath,
        'category': category,
        'created_at': createdAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      };

  factory Wallpaper.fromDbMap(Map<String, Object?> map) => Wallpaper(
        id: map['id'] as String,
        source: WallpaperSource.values.byName(map['source'] as String),
        thumbUrl: map['thumb_url'] as String,
        fullUrl: map['full_url'] as String,
        photographer: map['photographer'] as String,
        photographerUrl: (map['photographer_url'] ?? '') as String,
        pageUrl: (map['page_url'] ?? '') as String,
        avgColor: map['avg_color'] as String?,
        width: map['width'] as int?,
        height: map['height'] as int?,
      );
}

/// A wallpaper that has been downloaded to local storage.
class DownloadedWallpaper {
  const DownloadedWallpaper({
    required this.wallpaper,
    required this.filePath,
    required this.createdAt,
    this.category,
  });

  final Wallpaper wallpaper;

  /// Local file location; null when the record was restored from the cloud
  /// and the image file is not on this device yet.
  final String? filePath;
  final DateTime createdAt;
  final String? category;

  bool get hasLocalFile => filePath != null;

  factory DownloadedWallpaper.fromDbMap(Map<String, Object?> map) =>
      DownloadedWallpaper(
        wallpaper: Wallpaper.fromDbMap(map),
        filePath: map['file_path'] as String?,
        category: map['category'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
