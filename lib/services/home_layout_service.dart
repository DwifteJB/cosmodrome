import 'dart:async';

import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

final homeLayoutService = HomeLayoutService();

class HomeLayoutService extends ChangeNotifier {
  static const _scope = '_app';
  static const _key = 'home_layout';

  List<String>? _savedIds;
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  List<String> resolve(List<String> availableIds) {
    final saved = _savedIds;
    if (saved == null) return availableIds;
    return saved.where(availableIds.contains).toList();
  }

  void move(List<String> availableIds, String id, int delta) {
    final ids = resolve(availableIds);
    final from = ids.indexOf(id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) return;
    ids.insert(to, ids.removeAt(from));
    _update(ids);
  }

  void remove(List<String> availableIds, String id) =>
      _update(resolve(availableIds)..remove(id));

  void add(List<String> availableIds, String id) {
    final ids = resolve(availableIds);
    if (ids.contains(id)) return;
    _update(ids..add(id));
  }

  void reset() {
    _savedIds = null;
    notifyListeners();
    unawaited(_save(null));
  }

  void _update(List<String> ids) {
    _savedIds = ids;
    notifyListeners();
    unawaited(_save(ids));
  }

  Future<void> _load() async {
    try {
      final data = await LocalStorageService.readJsonMeta(_scope, _key);
      final ids = data?['sections'] as List<dynamic>?;
      if (ids != null) {
        _savedIds = ids.cast<String>();
        notifyListeners();
      }
    } catch (e) {
      loggerPrint('HomeLayout: failed to read layout: $e');
    }
  }

  Future<void> _save(List<String>? ids) async {
    try {
      await LocalStorageService.ensureDirs(_scope);
      await LocalStorageService.writeJsonMeta(_scope, _key, {'sections': ids});
    } catch (e) {
      loggerPrint('HomeLayout: failed to write layout: $e');
    }
  }
}
