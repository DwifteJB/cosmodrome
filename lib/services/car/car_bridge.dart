import 'dart:io';

import 'package:cosmodrome/services/car/car_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carplay/controllers/android_auto_controller.dart';
import 'package:flutter_carplay/controllers/carplay_controller.dart';
import 'package:flutter_carplay/flutter_carplay.dart';

const _channel = MethodChannel('me.rmfosho.cosmodrome/car');
const _iconTint = AutoImageTint.platform();

class AndroidAutoBridge extends CarBridge {
  static const _pageSize = 6;
  final FlutterAndroidAuto _auto = FlutterAndroidAuto();

  final Map<String, AAListTemplate> _templates = {};
  final Map<String, List<int>> _offsets = {};

  AndroidAutoBridge() {
    _auto.addListenerOnConnectionChange(
      (status) => onConnection?.call(status == ConnectionStatusTypes.connected),
    );
  }

  @override
  bool get connected =>
      FlutterAndroidAuto.connectionStatus ==
      ConnectionStatusTypes.connected.name;

  @override
  int get depth => FlutterAndroidAutoController.templateHistory.length;

  @override
  bool get presetsRoot => false;

  @override
  int get rowLimit => 100;

  @override
  bool get supportsTabs => false;

  @override
  int get visibleRows => _pageSize;

  @override
  bool isOpen(CarPage page) => FlutterAndroidAutoController.templateHistory.any(
    (template) => template.uniqueId == page.id,
  );

  @override
  Future<void> popToRoot() async {
    try {
      await FlutterAndroidAuto.popToRoot();
    } on PlatformException catch (_) {}
  }

  @override
  Future<bool> probe() async {
    try {
      await FlutterAndroidAuto.popToRoot();
      return true;
    } on PlatformException catch (error) {
      return error.code != 'No car context';
    }
  }

  @override
  Future<bool> push(CarPage page) async {
    final template = _template(page);
    try {
      final pushed = await FlutterAndroidAuto.push(template: template);
      if (pushed) _templates[page.id] = template;
      return pushed;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<void> setRoot(List<CarPage> tabs) async {
    final templates = tabs.map(_template).toList();
    try {
      await FlutterAndroidAuto.setRootTemplate(
        template: templates.length == 1
            ? templates.single
            : AATabBarTemplate(tabs: templates),
      );
      _offsets.clear();
      _templates
        ..clear()
        ..addEntries(templates.map((t) => MapEntry(t.uniqueId, t)));
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> showNowPlaying() async {
    try {
      if (await FlutterAndroidAuto.showSharedNowPlaying()) return;
      await _channel.invokeMethod<bool>('showNowPlaying');
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> update(CarPage page) async {
    final template = _templates[page.id];
    if (template == null) return;
    final sections = _sections(page);
    try {
      await _auto.updateListTemplateSections(
        elementId: page.id,
        sections: sections,
      );
      template.updateSections(sections);
    } on PlatformException catch (_) {
      _templates.remove(page.id);
    }
  }

  AAListItem _item(CarRow row) {
    final onTap = row.onTap;
    return AAListItem(
      title: row.playing ? '▶ ${row.title}' : row.title,
      subtitle: row.subtitle,
      imageUrl: row.image,
      imageTint: row.icon ? _iconTint : null,
      isBrowsable: row.browsable && onTap != null ? true : null,
      onPress: onTap == null
          ? null
          : (complete, _) async {
              try {
                await onTap();
              } catch (_) {
              } finally {
                try {
                  await complete();
                } catch (_) {}
              }
            },
    );
  }

  List<AAListSection> _sections(CarPage page) {
    final all = _limited(page);
    final total = all.fold<int>(0, (count, s) => count + s.rows.length);
    final groups = <(String?, List<AAListItem>)>[];

    if (total <= _pageSize) {
      for (final section in all) {
        groups.add((section.header, section.rows.map(_item).toList()));
      }
    } else {
      final stack = _offsets.putIfAbsent(page.id, () => [0]);
      while (stack.length > 1 && stack.last >= total) {
        stack.removeLast();
      }
      final offset = stack.last;
      final hasPrevious = offset > 0;
      var capacity = _pageSize - (hasPrevious ? 1 : 0);
      final hasMore = offset + capacity < total;
      if (hasMore) capacity--;

      var index = 0;
      for (final section in all) {
        final items = <AAListItem>[];
        for (final row in section.rows) {
          if (index >= offset && index < offset + capacity) {
            items.add(_item(row));
          }
          index++;
        }
        if (items.isNotEmpty) groups.add((section.header, items));
      }
      if (hasPrevious) {
        groups.first.$2.insert(
          0,
          _item(
            CarRow(
              title: 'Previous',
              onTap: () {
                stack.removeLast();
                return update(page);
              },
            ),
          ),
        );
      }
      if (hasMore) {
        groups.last.$2.add(
          _item(
            CarRow(
              title: 'More',
              subtitle: '${offset + capacity} of $total',
              onTap: () {
                stack.add(offset + capacity);
                return update(page);
              },
            ),
          ),
        );
      }
    }

    return [
      for (final group in groups)
        AAListSection(
          title: groups.length == 1 ? null : group.$1 ?? page.title,
          items: group.$2,
        ),
    ];
  }

  AAListTemplate _template(CarPage page) => AAListTemplate(
    id: page.id,
    title: page.title,
    tabTitle: page.title,
    iconUrl: page.tabIcon,
    sections: _sections(page),
    emptyViewTitleVariants: page.emptyText == null ? null : [page.emptyText!],
  );
}

abstract class CarBridge {
  void Function(bool connected)? onConnection;
  Future<void> Function()? onUpNext;
  Future<void> Function()? onToggleShuffle;
  Future<void> Function()? onToggleRepeat;

  bool get connected;
  int get depth;
  bool get presetsRoot;
  int get rowLimit;
  bool get supportsTabs;
  int get visibleRows;

  bool isOpen(CarPage page);
  Future<void> popToRoot();
  Future<bool> probe() async => connected;
  Future<bool> push(CarPage page);
  Future<void> setModes({
    required bool shuffle,
    required String repeat,
  }) async {}
  Future<void> setRoot(List<CarPage> tabs);
  Future<void> showNowPlaying();
  Future<void> update(CarPage page);

  List<CarSection> _limited(CarPage page) {
    var remaining = rowLimit;
    final sections = <CarSection>[];
    for (final section in page.sections) {
      if (remaining <= 0) break;
      if (section.rows.isEmpty) continue;
      final rows = section.rows.take(remaining).toList();
      remaining -= rows.length;
      sections.add(CarSection(header: section.header, rows: rows));
    }
    return sections;
  }

  static CarBridge? create() {
    if (kIsWeb) return null;
    if (Platform.isIOS) return CarPlayBridge();
    if (Platform.isAndroid) return AndroidAutoBridge();
    return null;
  }
}

class CarPlayBridge extends CarBridge {
  final FlutterCarplay _carplay = FlutterCarplay();

  CarPlayBridge() {
    _carplay.addListenerOnConnectionChange(
      (status) =>
          onConnection?.call(status != ConnectionStatusTypes.disconnected),
    );
    _channel.setMethodCallHandler((call) async {
      final handler = switch (call.method) {
        'upNext' => onUpNext,
        'toggleShuffle' => onToggleShuffle,
        'toggleRepeat' => onToggleRepeat,
        _ => null,
      };
      await handler?.call();
    });
  }

  @override
  bool get connected =>
      FlutterCarplay.connectionStatus == ConnectionStatusTypes.connected.name ||
      FlutterCarplay.connectionStatus == ConnectionStatusTypes.background.name;

  @override
  int get depth => FlutterCarPlayController.templateHistory.length;

  @override
  bool get presetsRoot => true;

  @override
  int get rowLimit => 200;

  @override
  bool get supportsTabs => true;

  @override
  int get visibleRows => 12;

  @override
  bool isOpen(CarPage page) => FlutterCarPlayController.templateHistory.any(
    (template) => template.uniqueId == page.id,
  );

  @override
  Future<void> popToRoot() async {
    try {
      await FlutterCarplay.popToRoot();
    } on PlatformException catch (_) {}
  }

  @override
  Future<bool> push(CarPage page) async {
    try {
      return await FlutterCarplay.push(template: _template(page));
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<void> setModes({required bool shuffle, required String repeat}) async {
    try {
      await _channel.invokeMethod<void>('setModes', {
        'shuffle': shuffle,
        'repeat': repeat,
      });
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> setRoot(List<CarPage> tabs) async {
    final templates = tabs.map(_template).toList();
    try {
      await FlutterCarplay.setRootTemplate(
        rootTemplate: templates.length == 1
            ? templates.single
            : CPTabBarTemplate(templates: templates),
      );
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> showNowPlaying() async {
    try {
      await FlutterCarplay.showSharedNowPlaying();
    } on PlatformException catch (_) {}
  }

  @override
  Future<void> update(CarPage page) async {
    try {
      await _carplay.updateListTemplateSections(
        elementId: page.id,
        sections: _sections(page),
      );
    } on PlatformException catch (_) {}
  }

  CPListItem _item(CarRow row) {
    final onTap = row.onTap;
    return CPListItem(
      text: row.title,
      detailText: row.subtitle,
      image: row.image,
      imageTint: row.icon ? _iconTint : null,
      isPlaying: row.playing ? true : null,
      playingIndicatorLocation: row.playing
          ? CPListItemPlayingIndicatorLocation.trailing
          : null,
      accessoryType: row.browsable
          ? CPListItemAccessoryType.disclosureIndicator
          : null,
      onPress: onTap == null
          ? null
          : (complete, _) async {
              try {
                await onTap();
              } catch (_) {
              } finally {
                try {
                  await complete();
                } catch (_) {}
              }
            },
    );
  }

  List<CPListSection> _sections(CarPage page) => [
    for (final section in _limited(page))
      CPListSection(
        header: section.header,
        sectionIndexEnabled: false,
        items: section.rows.map(_item).toList(),
      ),
  ];

  CPListTemplate _template(CarPage page) => CPListTemplate(
    id: page.id,
    title: page.title,
    tabTitle: page.title,
    systemIcon: page.symbol,
    sections: _sections(page),
    emptyViewTitleVariants: page.emptyText == null ? null : [page.emptyText!],
  );
}
