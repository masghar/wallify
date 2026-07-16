import 'dart:io';

import 'package:flutter/services.dart';

/// Where to apply the wallpaper on Android.
enum WallpaperTarget { home, lock, both }

/// Talks to the native side to apply wallpapers.
///
/// Capabilities per platform:
/// - Android: center-crops and scales the image to the exact screen
///   resolution, then sets home/lock/both via `WallpaperManager` — the
///   result always fills the display without stretching.
/// - macOS: sets the desktop picture for every screen, scaled to fill with
///   clipping (no letterboxing).
/// - iOS: apps cannot set wallpapers (OS restriction); the image is saved to
///   the Photos library instead so the user can apply it manually.
class WallpaperSetter {
  static const _channel = MethodChannel('wallify/platform');

  bool get canSetDirectly => Platform.isAndroid || Platform.isMacOS;

  bool get supportsTargets => Platform.isAndroid;

  /// Applies the image at [filePath]. On iOS this saves to Photos and returns
  /// normally; check [canSetDirectly] to adjust the UI copy.
  Future<void> apply(String filePath,
      {WallpaperTarget target = WallpaperTarget.both}) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      await _channel.invokeMethod<void>('setWallpaper', {
        'path': filePath,
        'target': target.name,
      });
    } else if (Platform.isIOS) {
      await _channel.invokeMethod<void>('saveToPhotos', {'path': filePath});
    } else {
      throw UnsupportedError(
          'Wallpaper setting is not supported on this platform');
    }
  }
}
