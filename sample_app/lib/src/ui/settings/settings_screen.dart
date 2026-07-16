import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/wallpaper_repository.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            toolbarHeight: 64,
            title: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    letterSpacing: -1.2,
                  ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              if (context.watch<AuthController>().isSupported) ...[
                const _SectionHeader('Account'),
                const _AccountCard(),
              ],
              const _SectionHeader('Appearance'),
              _SettingCard(
                children: [
                  ListTile(
                    title: const Text('Theme'),
                    trailing: SegmentedButton<ThemeMode>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto, size: 18)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode, size: 18)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode, size: 18)),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) =>
                          settings.setThemeMode(selection.first),
                      showSelectedIcon: false,
                    ),
                  ),
                  ListTile(
                    title: const Text('Grid columns'),
                    trailing: SegmentedButton<int>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {settings.gridColumns},
                      onSelectionChanged: (selection) =>
                          settings.setGridColumns(selection.first),
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
              const _SectionHeader('Photo sources'),
              _SettingCard(
                children: [
                  RadioGroup<PhotoSourceFilter>(
                    groupValue: settings.sourceFilter,
                    onChanged: (v) {
                      if (v != null) settings.setSourceFilter(v);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<PhotoSourceFilter>(
                          value: PhotoSourceFilter.all,
                          title: Text('Unsplash + Pexels'),
                          subtitle: Text('Mix results from both providers'),
                        ),
                        RadioListTile<PhotoSourceFilter>(
                          value: PhotoSourceFilter.unsplash,
                          title: Text('Unsplash only'),
                        ),
                        RadioListTile<PhotoSourceFilter>(
                          value: PhotoSourceFilter.pexels,
                          title: Text('Pexels only'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const _SectionHeader('About'),
              const _AboutCard(),
              const SizedBox(height: 112),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _signIn(BuildContext context) async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await auth.signIn();
      if (ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Signed in — restoring your library')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign-in failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return _SettingCard(
        children: [
          ListTile(
            leading: Icon(Icons.cloud_outlined, color: scheme.primary),
            title: const Text('Sign in with Google'),
            subtitle: const Text('Back up your saved wallpapers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _signIn(context),
          ),
        ],
      );
    }

    final photoUrl = user.photoUrl;
    final lastSynced = auth.lastSyncedAt;
    return _SettingCard(
      children: [
        ListTile(
          leading: CircleAvatar(
            foregroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: const Icon(Icons.person_outline),
          ),
          title: Text(user.displayName ?? user.email ?? 'Google account'),
          subtitle: Text(
            auth.syncing
                ? 'Syncing…'
                : lastSynced != null
                    ? 'Last synced ${DateFormat.yMMMd().add_jm().format(lastSynced)}'
                    : user.email ?? '',
          ),
          trailing: TextButton(
            onPressed: () => context.read<AuthController>().signOut(),
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser available; nothing useful to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      children: [
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 40,
                  height: 40,
                  cacheWidth: 120,
                ),
              ),
              title: const Text('Wallify'),
              subtitle: info == null
                  ? null
                  : Text('Version ${info.version} (${info.buildNumber})'),
            );
          },
        ),
        const ListTile(
          dense: true,
          subtitle: Text(
            'Free wallpapers from Unsplash and Pexels. '
            'Photos remain the property of their photographers.',
          ),
        ),
        ListTile(
          title: const Text('Wallpapers from Unsplash'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open('https://unsplash.com'),
        ),
        ListTile(
          title: const Text('…and Pexels'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open('https://www.pexels.com'),
        ),
        ListTile(
          title: const Text('Made by canabyte.ca'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open('https://canabyte.ca'),
        ),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) => ListTile(
            title: const Text('Open-source licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Wallify',
              applicationVersion: snapshot.data?.version,
            ),
          ),
        ),
      ],
    );
  }
}
