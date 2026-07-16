import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../models/wallpaper.dart';
import '../../state/downloads_controller.dart';
import '../../state/settings_controller.dart';
import '../detail/wallpaper_detail_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DownloadsController>();
    final columns = context.select<SettingsController, int>((s) => s.gridColumns);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            toolbarHeight: 64,
            title: Text(
              'Saved',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: -1.2,
                  ),
            ),
          ),
          if (!controller.loaded)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.downloads.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: controller.downloads.length,
                itemBuilder: (context, index) =>
                    _DownloadTile(download: controller.downloads[index]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 112)),
          ],
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.download});

  final DownloadedWallpaper download;

  double get _ratio => download.wallpaper.aspectRatio.clamp(0.55, 0.95);

  Future<void> _redownload(BuildContext context) async {
    final controller = context.read<DownloadsController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.redownload(download);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Download failed. Check your connection and '
                'try again.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final controller = context.read<DownloadsController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Saved?'),
        content: const Text(
            'This deletes the file from your device and removes it from '
            'your cloud backup on all devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.delete(download);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localPath = download.filePath;
    final downloading = context.select<DownloadsController, bool>(
        (c) => c.isDownloading(download.wallpaper.id));

    return AspectRatio(
      aspectRatio: _ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'wallpaper-${download.wallpaper.id}',
              child: localPath != null
                  ? Image.file(
                      File(localPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, _) => ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => CachedNetworkImage(
                        imageUrl: download.wallpaper.thumbUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                        placeholder: (context, _) => ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        errorWidget: (context, _, _) => ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.cloud_off_outlined),
                        ),
                      ),
                    ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WallpaperDetailScreen(
                      wallpaper: download.wallpaper,
                      localPath: localPath,
                    ),
                  ),
                ),
                onLongPress: () => _confirmDelete(context),
              ),
            ),
            if (!download.hasLocalFile)
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black38,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: downloading ? null : () => _redownload(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_download_outlined,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black38,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _confirmDelete(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wallpaper, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Nothing saved yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Wallpapers you save from Explore will live here,\neven when you\'re offline.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
