// user api for subsonic

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';
import 'package:cosmodrome/utils/logger.dart';

final Expando<SubsonicUser> _currentUserCache = Expando<SubsonicUser>();

SubsonicUser? _getCurrentUser(Subsonic subsonic) => _currentUserCache[subsonic];

void _setCurrentUser(Subsonic subsonic, SubsonicUser user) {
  _currentUserCache[subsonic] = user;
}

extension SubsonicUserApi on Subsonic {
  // https://www.subsonic.org/pages/api.jsp#getUser
  Future<SubsonicUser> getUser({
    String username = '',
    bool noCache = false,
  }) async {
    final grabUser = username.isEmpty ? auth.username : username;

    // if grabUser is current user and noCache is false, return cached user
    if (grabUser == auth.username && !noCache) {
      final cachedUser = _getCurrentUser(this);
      if (cachedUser != null) {
        loggerPrint('getUser: returning cached user ${cachedUser.username}');
        return cachedUser;
      }
    }

    loggerPrint("getting user info for $grabUser from server");

    try {
      final res = await apiRequest('getUser', params: {'username': grabUser});

      final userJson = res['user'] as Map<String, dynamic>;
      final user = SubsonicUser.fromJson(userJson);
      _setCurrentUser(this, user);
      return user;
    } catch (e) {
      loggerPrint('getUser failed: $e');
      rethrow;
    }
  }
}
