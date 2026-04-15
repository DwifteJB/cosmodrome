// basic api like ping, etc

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/utils/logger.dart';

extension SubsonicBasicApi on Subsonic {
  // via navidrome this should always be "valid" (since the license cannot expire)
  Future<String> getLicense() async {
    final res = await apiRequest('getLicense.view');
    final license = res['license'] as Map<String, dynamic>;
    return license['valid'] as String;
  }

  Future<({bool success, int? errorCode, String? errorMessage})> ping() async {
    try {
      await apiRequest('ping.view');
      return (success: true, errorCode: null, errorMessage: null);
    } catch (e) {
      loggerPrint('ping failed: $e');
      return (success: false, errorCode: null, errorMessage: e.toString());
    }
  }
}
