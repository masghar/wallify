import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/wallpaper.dart';
import '../../platform/wallpaper_setter.dart';
import '../../state/downloads_controller.dart';
import '../../state/explore_controller.dart';

/// Full-bleed preview: the photo owns the whole screen; controls float on
/// frosted glass above it.
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    required this.wallpaper,
    this.localPath,
    this.category,
  });

  final Wallpaper wallpaper;

  /// When opened from Saved, show the local file instead of the network.
  final String? localPath;

  /// Category label recorded with a download; defaults to the current
  /// Explore category.
  final String? category;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  bool _applying = false;

  Wallpaper get wallpaper => widget.wallpaper;

  Future<void> _download() async {
    final downloads = context.read<DownloadsController>();
    final category =
        widget.category ?? context.read<ExploreController>().category.title;
    try {
      await downloads.download(wallpaper, category: category);
      _showSnack('Saved — find it in the Saved tab');
    } catch (e) {
      _showSnack('Could not save. Check your connection and try again.');
    }
  }

  Future<void> _setWallpaper() async {
    final setter = WallpaperSetter();

    WallpaperTarget target = WallpaperTarget.both;
    if (setter.supportsTargets) {
      final selected = await showModalBottomSheet<WallpaperTarget>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home screen'),
                onTap: () => Navigator.pop(context, WallpaperTarget.home),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Lock screen'),
                onTap: () => Navigator.pop(context, WallpaperTarget.lock),
              ),
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text('Both'),
                onTap: () => Navigator.pop(context, WallpaperTarget.both),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (selected == null) return;
      target = selected;
    }

    if (!mounted) return;
    setState(() => _applying = true);
    try {
      final downloads = context.read<DownloadsController>();
      final path = widget.localPath ?? await downloads.download(wallpaper);
      await setter.apply(path, target: target);
      _showSnack(setter.canSetDirectly
          ? 'Wallpaper set'
          : 'Saved to Photos — apply it from the Photos app.');
    } catch (e) {
      _showSnack('Could not set wallpaper. Try again.');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAttribution() async {
    final url = wallpaper.pageUrl.isNotEmpty
        ? wallpaper.pageUrl
        : wallpaper.photographerUrl;
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsController>();
    final isDownloaded = downloads.isDownloaded(wallpaper.id);
    final isDownloading = downloads.isDownloading(wallpaper.id);
    final setter = WallpaperSetter();
    final padding = MediaQuery.paddingOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The wallpaper, exactly as it would look on a phone: cover-fit.
          // Preview uses the CDN's screen-sized rendition and a bounded
          // decode — never the multi-megabyte original.
          Hero(
            tag: 'wallpaper-${wallpaper.id}',
            child: widget.localPath != null
                ? Image.file(
                    File(widget.localPath!),
                    fit: BoxFit.cover,
                    cacheHeight:
                        (MediaQuery.sizeOf(context).height * dpr).round(),
                  )
                : CachedNetworkImage(
                    imageUrl: wallpaper.previewUrl,
                    fit: BoxFit.cover,
                    memCacheHeight:
                        (MediaQuery.sizeOf(context).height * dpr).round(),
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (context, _) => CachedNetworkImage(
                      imageUrl: wallpaper.thumbUrl,
                      fit: BoxFit.cover,
                    ),
                    errorWidget: (context, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 48),
                    ),
                  ),
          ),
          // Soft scrims so the floating controls always read.
          const _Scrim(alignment: Alignment.topCenter, height: 140),
          const _Scrim(alignment: Alignment.bottomCenter, height: 240),
          // Back button.
          Positioned(
            top: padding.top + 8,
            left: 16,
            child: _GlassCircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          // Action panel.
          Positioned(
            left: 16,
            right: 16,
            bottom: padding.bottom + 16,
            child: _GlassPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openAttribution,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              wallpaper.photographer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            wallpaper.source.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.north_east,
                              size: 12, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _applying ? null : _setWallpaper,
                          icon: _applying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black54),
                                )
                              : const Icon(Icons.wallpaper, size: 20),
                          label: Text(setter.canSetDirectly
                              ? 'Set as wallpaper'
                              : 'Save to Photos'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GlassCircleButton(
                        size: 52,
                        icon: isDownloaded
                            ? Icons.check
                            : Icons.arrow_downward_rounded,
                        busy: isDownloading,
                        onTap: isDownloaded || isDownloading ? null : _download,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.alignment, required this.height});

  final Alignment alignment;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: alignment == Alignment.topCenter
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              end: alignment == Alignment.topCenter
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
