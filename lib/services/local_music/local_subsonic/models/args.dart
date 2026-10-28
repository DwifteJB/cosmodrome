part of '../master_subsonic.dart';

class _Args {
  final String endpoint;
  final Map<String, dynamic> params;

  const _Args(this.endpoint, this.params);

  String? get(String key) {
    final value = params[key];
    if (value is List) return value.isEmpty ? null : '${value.first}';
    return value?.toString();
  }

  int integer(String key, int fallback) =>
      int.tryParse(get(key) ?? '') ?? fallback;

  List<String> list(String key) {
    final value = params[key];
    if (value == null) return [];
    return value is List ? [for (final v in value) '$v'] : ['$value'];
  }

  SubsonicApiException missing(String key) => SubsonicApiException(
    endpoint,
    _missingParameter,
    'required parameter is missing: $key',
  );

  SubsonicApiException notFound(String what) =>
      SubsonicApiException(endpoint, _notFound, '$what not found');

  String require(String key) => get(key) ?? (throw missing(key));
}
