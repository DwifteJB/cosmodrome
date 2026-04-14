import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class SubsonicAuth {
  final String username;
  final String password;

  SubsonicAuth({
    required this.username,
    required this.password,
  });

  // generate token as per api spec (https://www.subsonic.org/pages/api.jsp)
  SubsonicAuthToken generateToken() {
    final salt = _randomSalt();
    final bytes = utf8.encode(password + salt);
    final token = md5.convert(bytes).toString();
    return SubsonicAuthToken(salt: salt, token: token);
  }

  // generate token for salt
  static String _randomSalt({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

class SubsonicAuthToken {
  final String salt;
  final String token;

  const SubsonicAuthToken({required this.salt, required this.token});
}