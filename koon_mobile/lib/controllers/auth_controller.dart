import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../app/constants/api_constants.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final Rx<Map<String, dynamic>?> user = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      isLoggedIn.value = true;
      // Try to fetch fresh profile
      final profile = await _authService.getProfile();
      if (profile != null) {
        user.value = profile;
        await prefs.setString('user_data', jsonEncode(profile));
      } else {
        // Load cached profile
        final cached = prefs.getString('user_data');
        if (cached != null) {
          user.value = jsonDecode(cached);
        }
      }
    }
  }

  Future<bool> login(String email, String password) async {
    isLoading.value = true;
    try {
      final result = await _authService.login(email, password);
      if (result != null) {
        user.value = result['user'];
        isLoggedIn.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(result['user']));
        return true;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> register(String email, String password, String name, {String? phone}) async {
    isLoading.value = true;
    try {
      final result = await _authService.register(email, password, name, phone: phone);
      if (result != null) {
        user.value = result['user'];
        isLoggedIn.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(result['user']));
        return true;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> signInWithGoogle() async {
    isLoading.value = true;
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        user.value = result['user'];
        isLoggedIn.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(result['user']));
        return true;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<void> forgotPassword(String email) async {
    isLoading.value = true;
    try {
      await _authService.forgotPassword(email);
      Get.snackbar('Success', 'Reset link sent to your email', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    user.value = null;
    isLoggedIn.value = false;
  }

  String get userName => user.value?['name'] ?? '';
  String get userEmail => user.value?['email'] ?? '';
  String get userAvatar {
    final avatar = user.value?['avatar_url'] ?? '';
    if (avatar.startsWith('/')) {
      return '${ApiConstants.baseHost}$avatar';
    }
    return avatar;
  }
  double get userCredit => (user.value?['credit_balance'] ?? 0).toDouble();
}
