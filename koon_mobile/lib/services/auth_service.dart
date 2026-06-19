import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class AuthService {
  final Dio _dio = ApiService().dio;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        await _saveTokens(response.data);
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<Map<String, dynamic>?> register(String email, String password, String name, {String? phone}) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'name': name,
          if (phone != null) 'phone': phone,
        },
      );
      if (response.statusCode == 201) {
        await _saveTokens(response.data);
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return null;

      final response = await _dio.post(
        ApiConstants.googleAuth,
        data: {'id_token': idToken},
      );
      if (response.statusCode == 200) {
        await _saveTokens(response.data);
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
    return null;
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _dio.get(ApiConstants.userProfile);
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(ApiConstants.userProfile, data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post(
        '${ApiConstants.userProfile}/avatar',
        data: formData,
      );
      if (response.statusCode == 200) {
        return response.data['avatar_url'];
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
  }

  Future<Map<String, dynamic>?> verifyEmail(String code) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyEmail,
        data: {'code': code},
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<Map<String, dynamic>?> resendVerification() async {
    try {
      final response = await _dio.post(
        ApiConstants.resendVerification,
      );
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
    return null;
  }

  Future<bool> changePassword({String? currentPassword, required String newPassword}) async {
    try {
      final response = await _dio.put(
        ApiConstants.changePassword,
        data: {
          if (currentPassword != null) 'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token']);
    await prefs.setString('refresh_token', data['refresh_token']);
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map) {
      return e.response?.data['detail'] ?? 'An error occurred';
    }
    return e.message ?? 'Connection error';
  }
}
