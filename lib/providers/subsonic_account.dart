import 'dart:typed_data';

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';

class SubsonicAccount {
  // id is username@baseUrl
  final String id;
  final String baseUrl;
  final String username;
  Uint8List avatar = Uint8List(
    0,
  ); // fetched separately and cached in memory, not stored in json

  // Kept in memory and storage to allow recreating the Subsonic instance.
  final String _password;

  final SubsonicUser user;
  late final Subsonic subsonic;

  SubsonicAccount({
    required this.baseUrl,
    required this.username,
    required String password,
    required this.user,
  }) : id = '$username@$baseUrl',
       _password = password {
    subsonic = Subsonic(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  factory SubsonicAccount.fromJson(Map<String, dynamic> json) {
    return SubsonicAccount(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      user: SubsonicUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'password': _password,
    'user': user.toJson(),
  };
}
