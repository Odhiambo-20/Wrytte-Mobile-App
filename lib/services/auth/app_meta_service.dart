import 'api_service.dart';

class AppMetaService {
  AppMetaService._();
  static final AppMetaService instance = AppMetaService._();

  // PING (Health Check)

  Future<bool> ping() async {
    try {
      await ApiService.get("/api/ping", queryParameters: {});
      return true;
    } catch (_) {
      return false;
    }
  }

  // VERSION

  Future<Map<String, dynamic>> getVersion() async {
    return await ApiService.get("/api/version", queryParameters: {});
  }

  // STATS (Optional)

  Future<Map<String, dynamic>> getStats() async {
    return await ApiService.get("/api/stats", queryParameters: {});
  }
}
