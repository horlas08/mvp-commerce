import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;

  ApiService._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token silently — tokens are 10-year so this should
          // only happen if the server was wiped / secret key changed.
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request with new token
            final prefs = await SharedPreferences.getInstance();
            final newToken = prefs.getString('access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
          // Refresh also failed → pass the 401 error up so the caller's
          // catch/null-check handles it gracefully.  We NEVER force-logout;
          // the user stays logged in on the app side until they log out manually.
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio().post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await prefs.setString('access_token', response.data['access_token']);
        await prefs.setString('refresh_token', response.data['refresh_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
