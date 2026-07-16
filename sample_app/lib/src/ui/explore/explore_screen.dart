import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../data/wallpaper_repository.dart';
import '../../state/explore_controller.dart';
import '../../state/settings_controller.dart';
import '../detail/wallpaper_detail_screen.dart';
import '../search/search_screen.dart';
import 'wallpaper_tile.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ExploreController>();
      if (controller.feed.status == FeedStatus.initial) {
        controller.loadInitial();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 800) {
      context.read<ExploreController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExploreController>();
    final columns = context.select<SettingsController, int>((s) => s.gridColumns);
    final feed = controller.feed;

    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: 140,
        onRefresh: () => context.read<ExploreController>().refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              toolbarHeight: 64,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 28,
                      height: 28,
                      cacheWidth:
                          (28 * MediaQuery.devicePixelRatioOf(context)).round(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Wallify',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          letterSpacing: -1.2,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search, size: 26),
                  onPressed: () =>
                      Navigator.of(context).push(SearchScreen.route(context)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: WallpaperCategory.defaults.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = WallpaperCategory.defaults[index];
                    final selected =
                        category.title == controller.category.title;
                    return ChoiceChip(
                      label: Text(category.title),
                      selected: selected,
                      side: selected ? BorderSide.none : null,
                      onSelected: (_) => controller.selectCategory(category),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ..._buildFeedSlivers(feed, columns),
            // Breathing room behind the floating nav.
            const SliverToBoxAdapter(child: SizedBox(height: 112)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeedSlivers(CategoryFeed feed, int columns) {
    switch (feed.status) {
      case FeedStatus.initial:
      case FeedStatus.loading:
        return [
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case FeedStatus.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorView(
              message: feed.errorMessage ?? 'Something went wrong.',
              onRetry: () => context.read<ExploreController>().loadInitial(),
            ),
          ),
        ];
      case FeedStatus.ready:
      case FeedStatus.loadingMore:
        if (feed.items.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorView(
                message: 'No wallpapers found here yet.',
                onRetry: () => context.read<ExploreController>().refresh(),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childCount: feed.items.length,
              itemBuilder: (context, index) {
                final wallpaper = feed.items[index];
                return WallpaperTile(
                  wallpaper: wallpaper,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WallpaperDetailScreen(wallpaper: wallpaper),
                    ),
                  ),
                );
              },
            ),
          ),
          if (feed.status == FeedStatus.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
        ];
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
