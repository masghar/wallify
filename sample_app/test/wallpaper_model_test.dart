import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/src/models/wallpaper.dart';

void main() {
  group('Wallpaper.fromUnsplashJson', () {
    test('parses a typical search result item', () {
      final json = {
        'id': 'AbC123',
        'width': 4000,
        'height': 6000,
        'color': '#0c2636',
        'urls': {
          'raw': 'https://images.unsplash.com/raw',
          'full': 'https://images.unsplash.com/full',
          'regular': 'https://images.unsplash.com/regular',
          'small': 'https://images.unsplash.com/small',
        },
        'links': {
          'html': 'https://unsplash.com/photos/AbC123',
          'download_location': 'https://api.unsplash.com/photos/AbC123/download',
        },
        'user': {
          'name': 'Jane Doe',
          'links': {'html': 'https://unsplash.com/@janedoe'},
        },
      };

      final w = Wallpaper.fromUnsplashJson(json);

      expect(w.id, 'unsplash:AbC123');
      expect(w.source, WallpaperSource.unsplash);
      expect(w.thumbUrl, 'https://images.unsplash.com/small');
      expect(w.fullUrl, 'https://images.unsplash.com/full');
      expect(w.previewUrl, 'https://images.unsplash.com/regular');
      expect(w.photographer, 'Jane Doe');
      expect(w.photographerUrl, 'https://unsplash.com/@janedoe');
      expect(w.pageUrl, 'https://unsplash.com/photos/AbC123');
      expect(w.downloadLocation,
          'https://api.unsplash.com/photos/AbC123/download');
      expect(w.avgColor, '#0c2636');
      expect(w.aspectRatio, closeTo(4000 / 6000, 0.0001));
    });

    test('tolerates missing optional fields', () {
      final w = Wallpaper.fromUnsplashJson({'id': 'x'});
      expect(w.id, 'unsplash:x');
      expect(w.photographer, 'Unknown');
      expect(w.aspectRatio, 0.7);
    });
  });

  group('Wallpaper.fromPexelsJson', () {
    test('parses a typical search result item', () {
      final json = {
        'id': 99887,
        'width': 3000,
        'height': 4500,
        'url': 'https://www.pexels.com/photo/99887/',
        'photographer': 'John Roe',
        'photographer_url': 'https://www.pexels.com/@johnroe',
        'avg_color': '#334455',
        'src': {
          'original': 'https://images.pexels.com/original.jpg',
          'large2x': 'https://images.pexels.com/large2x.jpg',
          'medium': 'https://images.pexels.com/medium.jpg',
        },
      };

      final w = Wallpaper.fromPexelsJson(json);

      expect(w.id, 'pexels:99887');
      expect(w.source, WallpaperSource.pexels);
      expect(w.thumbUrl, 'https://images.pexels.com/medium.jpg');
      expect(w.fullUrl, 'https://images.pexels.com/original.jpg');
      expect(w.previewUrl, 'https://images.pexels.com/large2x.jpg');
      expect(w.photographer, 'John Roe');
      expect(w.pageUrl, 'https://www.pexels.com/photo/99887/');
      expect(w.downloadLocation, isNull);
    });
  });

  group('downloadUrl', () {
    test('asks the Unsplash CDN for a resized rendition, keeping params', () {
      const w = Wallpaper(
        id: 'unsplash:a',
        source: WallpaperSource.unsplash,
        thumbUrl: 't',
        fullUrl: 'https://images.unsplash.com/photo-1?ixid=xyz&q=85',
        photographer: 'p',
        photographerUrl: '',
        pageUrl: '',
      );

      final uri = Uri.parse(w.downloadUrl(targetWidth: 2000));

      expect(uri.queryParameters['w'], '2000');
      expect(uri.queryParameters['fit'], 'max');
      expect(uri.queryParameters['fm'], 'jpg');
      expect(uri.queryParameters['ixid'], 'xyz', reason: 'existing params kept');
    });

    test('asks the Pexels CDN for a compressed resized rendition', () {
      const w = Wallpaper(
        id: 'pexels:1',
        source: WallpaperSource.pexels,
        thumbUrl: 't',
        fullUrl: 'https://images.pexels.com/photos/1/pexels-photo-1.jpeg',
        photographer: 'p',
        photographerUrl: '',
        pageUrl: '',
      );

      final uri = Uri.parse(w.downloadUrl());

      expect(uri.queryParameters['w'], '2880');
      expect(uri.queryParameters['auto'], 'compress');
      expect(uri.queryParameters['cs'], 'tinysrgb');
    });
  });

  group('DB round trip', () {
    test('toDbMap / fromDbMap preserve the wallpaper', () {
      const original = Wallpaper(
        id: 'pexels:1',
        source: WallpaperSource.pexels,
        thumbUrl: 't',
        fullUrl: 'f',
        photographer: 'p',
        photographerUrl: 'pu',
        pageUrl: 'pg',
        avgColor: '#112233',
        width: 100,
        height: 200,
      );

      final map = original.toDbMap(filePath: '/tmp/x.jpg', category: 'Nature');
      final restored = Wallpaper.fromDbMap(map);

      expect(restored.id, original.id);
      expect(restored.source, original.source);
      expect(restored.thumbUrl, original.thumbUrl);
      expect(restored.fullUrl, original.fullUrl);
      expect(restored.photographer, original.photographer);
      expect(restored.width, 100);
      expect(restored.height, 200);
    });
  });
}
