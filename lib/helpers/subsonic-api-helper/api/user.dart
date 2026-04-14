// user api for subsonic

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/utils/logger.dart';

final Expando<SubsonicUser> _currentUserCache = Expando<SubsonicUser>();

SubsonicUser? _getCurrentUser(Subsonic subsonic) => _currentUserCache[subsonic];

void _setCurrentUser(Subsonic subsonic, SubsonicUser user) {
  _currentUserCache[subsonic] = user;
}

class SubsonicUser {
  /*
  https://www.subsonic.org/pages/inc/api/examples/user_example_1.xml
  */
  String username;
  String? email;

  List<dynamic> folders = [];

  // optional //
  bool scrobblingEnabled;
  bool adminRole;
  bool settingsRole;
  bool downloadRole;
  bool uploadRole;
  bool playlistRole;
  bool coverArtRole;
  bool commentRole;
  bool podcastRole;
  bool streamRole;
  bool jukeboxRole;
  bool shareRole;

  SubsonicUser({
    required this.username,
    this.email,
    this.folders = const [],
    this.scrobblingEnabled = false,
    this.adminRole = false,
    this.settingsRole = false,
    this.downloadRole = false,
    this.uploadRole = false,
    this.playlistRole = false,
    this.coverArtRole = false,
    this.commentRole = false,
    this.podcastRole = false,
    this.streamRole = false,
    this.jukeboxRole = false,
    this.shareRole = false,
  });

  // from json
  factory SubsonicUser.fromJson(Map<String, dynamic> json) {
    return SubsonicUser(
      username: json['username'] as String,
      email: json['email'] as String?,
      folders: json['folder'] as List<dynamic>? ?? const [],
      scrobblingEnabled: json['scrobblingEnabled'] as bool? ?? false,
      adminRole: json['adminRole'] as bool? ?? false,
      settingsRole: json['settingsRole'] as bool? ?? false,
      downloadRole: json['downloadRole'] as bool? ?? false,
      uploadRole: json['uploadRole'] as bool? ?? false,
      playlistRole: json['playlistRole'] as bool? ?? false,
      coverArtRole: json['coverArtRole'] as bool? ?? false,
      commentRole: json['commentRole'] as bool? ?? false,
      podcastRole: json['podcastRole'] as bool? ?? false,
      streamRole: json['streamRole'] as bool? ?? false,
      jukeboxRole: json['jukeboxRole'] as bool? ?? false,
      shareRole: json['shareRole'] as bool? ?? false,
    );
  }

  // to json
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'folder': folders,
      'scrobblingEnabled': scrobblingEnabled,
      'adminRole': adminRole,
      'settingsRole': settingsRole,
      'downloadRole': downloadRole,
      'uploadRole': uploadRole,
      'playlistRole': playlistRole,
      'coverArtRole': coverArtRole,
      'commentRole': commentRole,
      'podcastRole': podcastRole,
      'streamRole': streamRole,
      'jukeboxRole': jukeboxRole,
      'shareRole': shareRole,
    };
  }
}

extension SubsonicUserApi on Subsonic {
  // hidden property
  
  // https://www.subsonic.org/pages/api.jsp#getUser
  Future<SubsonicUser> getUser({
    String username = '',
    bool noCache = false
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
      final res = await apiRequest('getUser', params: {
        'username': grabUser,
      });

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