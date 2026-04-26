import 'dart:async';

import 'package:cosmodrome/components/album_card.dart';
import 'package:cosmodrome/components/shared_views/no_account_view.dart';
import 'package:cosmodrome/components/shared_views/no_content_view.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StarredAlbumsPage extends StatefulWidget {
  const StarredAlbumsPage({super.key});

  @override
  State<StarredAlbumsPage> createState() => _StarredAlbumsPageState();
}

class _StarredAlbumsPageState extends State<StarredAlbumsPage>
    with LayoutPageMixin {
  List<Album>? _albums;
  bool _loading = true;
  bool _hasAccount = true;

  @override
  String? get pageTitle => 'Starred Albums';

  @override
  Widget build(BuildContext context) {
    if (!_hasAccount) return const NoAccountView();

    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
      );
    }

    if (_albums == null || _albums!.isEmpty) return const NoContentView(contentType: 'starred albums');

    final subsonic = context.read<SubsonicProvider>().subsonic;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
      child: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 28,
          alignment: WrapAlignment.center,
          children: _albums!
              .map((album) => AlbumCard(album: album, subsonic: subsonic))
              .toList(growable: false),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums({bool forceRefresh = false}) async {
    final provider = context.read<SubsonicProvider>();
    final accountId = provider.activeAccount?.id;
    if (accountId == null) {
      setState(() {
        _loading = false;
        _albums = null;
        _hasAccount = false;
      });
      return;
    }

    if (forceRefresh) setState(() => _loading = true);

    final cachedRecent = await offlineCacheService.loadRecentAlbums(accountId);

    if (provider.isOffline) {
      if (mounted) setState(() { _albums = cachedRecent; _loading = false; });
      return;
    }

    if (mounted && cachedRecent != null) {
      setState(() { _albums = cachedRecent; _loading = false; });
    }

    if (!mounted) return;
    setState(() => _loading = _albums == null);

    try {
      final starred = await provider.subsonic.getAlbumList2(
        'starred',
        size: 20,
        forceRefresh: forceRefresh,
      );

      await offlineCacheService.saveStarredAlbums(accountId, starred);

      if (mounted) setState(() { _albums = starred; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _albums = cachedRecent; _loading = false; });
      unawaited(provider.checkConnectivity());
    }
  }
}
