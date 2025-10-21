import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  Future<void> checkAndUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // ignore
    }
  }
}
