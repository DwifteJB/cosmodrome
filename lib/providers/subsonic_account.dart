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

  final String password;

  final SubsonicUser user;
  final Subsonic subsonic;

  int timeoutSeconds;

  SubsonicAccount({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.user,
    this.timeoutSeconds = 15,
    SubsonicLoginMethod loginMethod = SubsonicLoginMethod.undetermined,
  }) : id = '$username@$baseUrl',
       subsonic = Subsonic(
         baseUrl: baseUrl,
         username: username,
         password: password,
         timeoutSeconds: timeoutSeconds,
       ) {
    subsonic.loginMethod = loginMethod;
  }

  factory SubsonicAccount.fromJson(Map<String, dynamic> json) {
    return SubsonicAccount(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      user: SubsonicUser.fromJson(json['user'] as Map<String, dynamic>),
      // accounts saved before this was stored get probed on first request
      loginMethod:
          SubsonicLoginMethod.values.asNameMap()[json['loginMethod']] ??
          SubsonicLoginMethod.undetermined,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'password': password,
    'user': user.toJson(),
    'loginMethod': subsonic.loginMethod.name,
  };
}
