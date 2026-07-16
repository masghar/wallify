import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/wallpaper_repository.dart';
import '../../state/explore_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/wallpaper_search_controller.dart';
import '../detail/wallpaper_detail_screen.dart';
import '../explore/wallpaper_tile.dart';

/// Full-screen search across Unsplash and Pexels.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => WallpaperSearchController(
          repository: context.read<WallpaperRepository>(),
          database: context.read<AppDatabase>(),
          settings: context.read<SettingsController>(),
        ),
        child: const SearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _SearchView();
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Bring up the keyboard right away — searching is why we're here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 800) {
      context.read<WallpaperSearchController>().loadMore();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runRecent(String query) {
    _textController.text = query;
    _focusNode.unfocus();
    context.read<WallpaperSearchController>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WallpaperSearchController>();
    final columns = context.select<SettingsController, int>((s) => s.gridColumns);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            onChanged: controller.onQueryChanged,
            onSubmitted: controller.search,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.inter(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search wallpapers…',
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              suffixIcon: controller.query.isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _textController.clear();
                        controller.onQueryChanged('');
                        _focusNode.requestFocus();
                      },
                    ),
            ),
          ),
        ),
      ),
      body: _buildBody(controller, columns),
    );
  }

  Widget _buildBody(WallpaperSearchController controller, int columns) {
    final feed = controller.feed;

    switch (feed.status) {
      case FeedStatus.initial:
        return _RecentSearches(onTap: _runRecent);
      case FeedStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case FeedStatus.error:
        return _Message(
          icon: Icons.cloud_off,
          text: feed.errorMessage ?? 'Something went wrong.',
          action: FilledButton.tonal(
            onPressed: () => controller.search(controller.query),
            child: const Text('Retry'),
          ),
        );
      case FeedStatus.ready:
      case FeedStatus.loadingMore:
        if (feed.items.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            text: 'No wallpapers match "${controller.query}".\nTry a different word.',
          );
        }
        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                        builder: (_) => WallpaperDetailScreen(
                          wallpaper: wallpaper,
                          category: controller.query,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (feed.status == FeedStatus.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WallpaperSearchController>();
    final scheme = Theme.of(context).colorScheme;

    if (controller.recents.isEmpty) {
      return const _Message(
        icon: Icons.search,
        text: 'Search across Unsplash and Pexels.\nTry "aurora", "koi pond" or "brutalism".',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton(
              onPressed: controller.clearRecents,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in controller.recents)
              ActionChip(
                avatar: Icon(Icons.history,
                    size: 16, color: scheme.onSurfaceVariant),
                label: Text(query),
                onPressed: () => onTap(query),
              ),
          ],
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
