import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/wallpaper.dart';

/// Masonry tile: the photo at its true aspect ratio, softly faded in,
/// with a whisper of photographer credit.
class WallpaperTile extends StatelessWidget {
  const WallpaperTile({super.key, required this.wallpaper, required this.onTap});

  final Wallpaper wallpaper;
  final VoidCallback onTap;

  /// Clamp extreme panoramas/towers so the grid keeps its rhythm.
  double get _ratio => wallpaper.aspectRatio.clamp(0.55, 0.95);

  Color _placeholderColor(BuildContext context) {
    final hex = wallpaper.avgColor;
    if (hex != null && hex.startsWith('#') && hex.length == 7) {
      final value = int.tryParse(hex.substring(1), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return AspectRatio(
      aspectRatio: _ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'wallpaper-${wallpaper.id}',
              child: LayoutBuilder(
                builder: (context, constraints) => CachedNetworkImage(
                  imageUrl: wallpaper.thumbUrl,
                  fit: BoxFit.cover,
                  // Decode at the displayed size, not the intrinsic size —
                  // keeps hundreds of grid thumbs cheap in memory.
                  memCacheWidth: constraints.maxWidth.isFinite
                      ? (constraints.maxWidth * dpr).round()
                      : null,
                  fadeInDuration: const Duration(milliseconds: 350),
                  placeholder: (context, _) =>
                      ColoredBox(color: _placeholderColor(context)),
                  errorWidget: (context, _, _) => ColoredBox(
                    color: _placeholderColor(context),
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                wallpaper.photographer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                ),
              ),
            ),
            Semantics(
              button: true,
              label:
                  'Wallpaper by ${wallpaper.photographer} on ${wallpaper.source.label}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
