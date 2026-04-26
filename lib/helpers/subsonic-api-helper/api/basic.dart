// basic api like ping, etc

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/utils/logger/logger.dart';

extension SubsonicBasicApi on Subsonic {
  // via navidrome this should always be "valid" (since the license cannot expire)
  Future<String> getLicense() async {
    final res = await apiRequest('getLicense.view');
    final license = res['license'] as Map<String, dynamic>;
    return license['valid'] as String;
  }

  // https://www.subsonic.org/pages/api.jsp#getScanStatus
  Future<({bool scanning, int count, String? errorMessage})>
  getScanStatus() async {
    try {
      var res = await apiRequest('getScanStatus');
      final scanResults = res['scanStatus'] as Map<String, dynamic>;

      return (
        scanning: scanResults['scanning'] as bool,
        count: scanResults['count'] as int,
        errorMessage: null,
      );
    } catch (e) {
      return (scanning: false, count: 0, errorMessage: e.toString());
    }
  }

  Future<({bool success, int? errorCode, String? errorMessage})> ping({
    int timeoutSeconds = 5,
  }) async {
    try {
      await apiRequest('ping.view', timeoutSeconds: timeoutSeconds);
      return (success: true, errorCode: null, errorMessage: null);
    } catch (e) {
      return (success: false, errorCode: null, errorMessage: e.toString());
    }
  }

  // https://www.subsonic.org/pages/api.jsp#startScan
  Future<({bool scanning, int count, String? errorMessage})> startScan() async {
    try {
      var res = await apiRequest('startScan');
      final scanResults = res['scanStatus'] as Map<String, dynamic>;

      return (
        scanning: scanResults['scanning'] as bool,
        count: scanResults['count'] as int,
        errorMessage: null,
      );
    } catch (e) {
      loggerPrint("scan failed $e");
      return (scanning: false, count: 0, errorMessage: e.toString());
    }
  }
}
