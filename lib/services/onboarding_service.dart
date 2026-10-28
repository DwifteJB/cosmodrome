import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';

class OnboardingService {
  static const _scope = '_app';
  static const _key = 'onboarding';

  static Future<bool> isComplete() async {
    try {
      final data = await LocalStorageService.readJsonMeta(_scope, _key);
      return data?['complete'] == true;
    } catch (e) {
      loggerPrint('Onboarding: failed to read state: $e');
      return false;
    }
  }

  static Future<void> markComplete() async {
    try {
      await LocalStorageService.ensureDirs(_scope);
      await LocalStorageService.writeJsonMeta(_scope, _key, {'complete': true});
    } catch (e) {
      loggerPrint('Onboarding: failed to write state: $e');
    }
  }
}
