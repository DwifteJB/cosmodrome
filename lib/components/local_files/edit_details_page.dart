import 'dart:math';
import 'dart:typed_data';

import 'package:cosmodrome/components/settings/settings_shell.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/local_music/local_tags.dart';
import 'package:cosmodrome/services/local_music/tag_lookup_service.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

Future<void> showEditDetails(BuildContext context, Song song) {
  if (isMobile(context)) {
    return showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.92,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) =>
          MobileSettingsSheetWrapper(child: EditDetailsPage(song: song)),
    );
  }

  return showFDialog(
    context: context,
    builder: (dialogCtx, _, animation) => FDialog.raw(
      animation: animation,
      builder: (innerCtx, style) => SizedBox(
        width: 520,
        height: min(720, MediaQuery.sizeOf(innerCtx).height * 0.85),
        child: EditDetailsPage(song: song),
      ),
    ),
  );
}

class EditDetailsPage extends StatefulWidget {
  final Song song;

  const EditDetailsPage({super.key, required this.song});

  @override
  State<EditDetailsPage> createState() => _EditDetailsPageState();
}

class _EditDetailsPageState extends State<EditDetailsPage>
    with TickerProviderStateMixin {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _album = TextEditingController();
  final _albumArtist = TextEditingController();
  final _track = TextEditingController();
  final _disc = TextEditingController();
  final _year = TextEditingController();
  final _genre = TextEditingController();
  late final FPopoverController _artMenu;

  LocalTrack? _source;
  Uint8List? _picture;
  bool _pictureChanged = false;
  bool _loadingPicture = false;

  List<TagMatch>? _matches;
  bool _lookingUp = false;
  List<String>? _artwork;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _artMenu = FPopoverController(vsync: this);
    final track = localMusicService.track(widget.song.id);
    _source = track;
    final song = track?.song ?? widget.song;
    _title.text = song.title;
    _artist.text = song.artist ?? '';
    _album.text = song.album ?? '';
    _albumArtist.text = track?.albumArtist ?? '';
    _track.text = song.track?.toString() ?? '';
    _disc.text = song.discNumber?.toString() ?? '';
    _year.text = track?.year?.toString() ?? '';
    _genre.text = track?.genre ?? '';
    _loadPicture(song.coverArt);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _artist,
      _album,
      _albumArtist,
      _track,
      _disc,
      _year,
      _genre,
    ]) {
      c.dispose();
    }
    _artMenu.dispose();
    super.dispose();
  }

  Future<void> _loadPicture(String? artId) async {
    if (artId == null || !isLocalArtId(artId)) return;
    setState(() => _loadingPicture = true);
    final bytes = await localMusicService.artBytes(artId);
    if (!mounted) return;
    setState(() {
      _picture ??= bytes;
      _loadingPicture = false;
    });
  }

  void _toast(String message) =>
      showFToast(context: context, title: Text(message));

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  int? _number(TextEditingController c) =>
      int.tryParse(c.text.trim().split('/').first.trim());

  Future<List<TagMatch>> _lookUp() async {
    final title = _text(_title);
    if (title == null) {
      setState(() => _error = 'Add a title to look up details');
      return const [];
    }
    setState(() {
      _lookingUp = true;
      _error = null;
    });
    final matches = await tagLookupService.lookup(
      title: title,
      artist: _text(_artist),
      album: _text(_album),
    );
    if (mounted) {
      setState(() {
        _matches = matches;
        _lookingUp = false;
      });
    }
    return matches;
  }

  Future<void> _findArtwork() async {
    final matches = _matches ?? await _lookUp();
    if (!mounted) return;
    final artwork = tagLookupService.artwork(matches);
    setState(() => _artwork = artwork);
    if (artwork.isEmpty) _toast('No artwork found');
  }

  Future<void> _apply(TagMatch match) async {
    void set(TextEditingController c, Object? value) {
      if (value != null) c.text = '$value';
    }

    setState(() {
      set(_title, match.title);
      set(_artist, match.artist);
      set(_album, match.album);
      set(_albumArtist, match.albumArtist);
      set(_track, match.track);
      set(_disc, match.disc);
      set(_year, match.year);
      set(_genre, match.genre);
    });

    final url = match.imageUrl;
    if (url != null) await _useImage(url, quiet: true);
  }

  Future<void> _useImage(String url, {bool quiet = false}) async {
    setState(() => _loadingPicture = true);
    final bytes = await tagLookupService.image(url);
    if (!mounted) return;
    setState(() {
      _loadingPicture = false;
      if (bytes != null) {
        _picture = bytes;
        _pictureChanged = true;
      }
    });
    if (bytes == null && !quiet) _toast("Couldn't load that image");
  }

  Future<void> _chooseImage() async {
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose image',
        type: FileType.image,
      );
      if (picked.isEmpty) return;
      final bytes = await picked.first.readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      setState(() {
        _picture = bytes;
        _pictureChanged = true;
      });
    } catch (e) {
      loggerPrint('EditDetails: image picker failed: $e');
    }
  }

  void _removeImage() => setState(() {
    _picture = null;
    _pictureChanged = true;
  });

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await localMusicService.editTags(
      widget.song,
      LocalTagEdit(
        title: _text(_title),
        artist: _text(_artist),
        albumArtist: _text(_albumArtist),
        album: _text(_album),
        track: _number(_track),
        disc: _number(_disc),
        year: _number(_year),
        genre: _text(_genre),
        picture: _picture,
        pictureChanged: _pictureChanged,
      ),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _error = "Couldn't save changes to this file";
      });
      return;
    }
    _toast('Saved changes');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Text(
                'Edit Details',
                style: typography.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    FIcons.x,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(colors, typography),
                const SizedBox(height: 16),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: _lookingUp || _saving ? null : _lookUp,
                  prefix: _lookingUp
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(FIcons.search),
                  child: Text(_lookingUp ? 'Looking up…' : 'Look Up Details'),
                ),
                if (_matches != null) ...[
                  const SizedBox(height: 12),
                  _matchList(colors, typography),
                ],
                if (_artwork != null && _artwork!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _artworkPicker(colors, typography),
                ],
                const SizedBox(height: 20),
                _field('Title', _title),
                _field('Artist', _artist),
                _field('Album', _album),
                _field('Album Artist', _albumArtist),
                Row(
                  children: [
                    Expanded(child: _field('Track', _track, number: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Disc', _disc, number: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Year', _year, number: true)),
                  ],
                ),
                _field('Genre', _genre),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: typography.sm.copyWith(color: colors.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FButton(
                  onPress: _saving || _loadingPicture ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
                const SizedBox(height: 8),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(FColors colors, FTypography typography) {
    return Row(
      children: [
        _cover(colors),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _source?.name.split('/').last ?? widget.song.title,
                style: typography.sm.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Hold or right click the artwork to change it',
                style: typography.xs.copyWith(color: colors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(FColors colors) {
    const size = 112.0;
    final picture = _picture;

    final art = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picture != null)
              Image.memory(
                picture,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder(colors),
              )
            else
              _placeholder(colors),
            if (_loadingPicture)
              ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.foreground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return FPopover(
      control: FPopoverControl.managed(controller: _artMenu),
      popoverAnchor: Alignment.topLeft,
      childAnchor: Alignment.bottomLeft,
      popoverBuilder: (context, controller) => Padding(
        padding: const EdgeInsets.all(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
          child: FItemGroup(
            children: [
              FItem(
                prefix: const Icon(FIcons.search, size: 16),
                title: const Text('Find artwork'),
                onPress: () {
                  controller.hide();
                  _findArtwork();
                },
              ),
              FItem(
                prefix: const Icon(FIcons.imagePlus, size: 16),
                title: const Text('Choose image'),
                onPress: () {
                  controller.hide();
                  _chooseImage();
                },
              ),
              if (picture != null)
                FItem(
                  prefix: const Icon(
                    FIcons.trash2,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Remove image',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onPress: () {
                    controller.hide();
                    _removeImage();
                  },
                ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        onTap: _artMenu.toggle,
        onLongPress: _artMenu.show,
        onSecondaryTap: _artMenu.show,
        child: art,
      ),
    );
  }

  Widget _placeholder(FColors colors) => ColoredBox(
    color: colors.muted,
    child: Icon(FIcons.music, color: colors.mutedForeground, size: 36),
  );

  Widget _matchList(FColors colors, FTypography typography) {
    final matches = _matches!;
    if (matches.isEmpty) {
      return Text(
        'No matches found',
        style: typography.sm.copyWith(color: colors.mutedForeground),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: matches.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
        itemBuilder: (context, i) {
          final match = matches[i];
          return TapArea(
            onTap: _saving ? null : () => _apply(match),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.title ?? match.album ?? '',
                        style: typography.sm.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (match.summary.isNotEmpty)
                        Text(
                          match.summary,
                          style: typography.xs.copyWith(
                            color: colors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  match.source,
                  style: typography.xs.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _artworkPicker(FColors colors, FTypography typography) {
    final artwork = _artwork!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artwork',
          style: typography.sm.copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: artwork.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => TapArea(
              onTap: () => _useImage(artwork[i]),
              borderRadius: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  artwork[i],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FTextField(
        label: Text(label),
        control: FTextFieldControl.managed(controller: controller),
        keyboardType: number ? TextInputType.number : null,
        autocorrect: false,
        enabled: !_saving,
      ),
    );
  }
}
