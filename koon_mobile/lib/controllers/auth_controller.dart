import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../app/constants/api_constants.dart';
import '../app/utils/app_snackbar.dart';

/// Result of a login attempt — lets the UI decide what to show/navigate to.
enum LoginResult {
  success,
  needsVerification, // logged in but email not yet verified
  failed,
}

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
      final profile = await _authService.getProfile();
      if (profile != null) {
        user.value = profile;
        await prefs.setString('user_data', jsonEncode(profile));
      } else {
        final cached = prefs.getString('user_data');
        if (cached != null) {
          user.value = jsonDecode(cached);
        }
      }
    }
  }

  /// Returns [LoginResult].
  /// Throws [UserNotFoundException] when the email is not registered.
  Future<LoginResult> login(String email, String password) async {
    isLoading.value = true;
    try {
      final result = await _authService.login(email, password);
      if (result != null) {
        user.value = result['user'];
        isLoggedIn.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(result['user']));

        // If the user has an unverified email the backend sends back the code.
        // Auto-resend and tell the caller to navigate to the verify screen.
        final debugCode = result['debug_code'];
        if (debugCode != null) {
          await resendVerification(); // silently resend so the inbox is fresh
          return LoginResult.needsVerification;
        }
        return LoginResult.success;
      }
    } on UserNotFoundException {
      rethrow; // caller redirects to RegisterScreen
    } catch (e) {
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return LoginResult.failed;
  }

  /// Returns true on success. Caller handles navigation to EmailVerificationScreen.
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
      AppSnackbar.error(null, e.toString());
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
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  /// Throws [UserNotFoundException] if the email is not registered.
  Future<bool> forgotPassword(String email) async {
    isLoading.value = true;
    try {
      final res = await _authService.forgotPassword(email);
      if (res != null) {
        return true;
      }
    } on UserNotFoundException {
      rethrow; // ForgotPasswordScreen shows inline error
    } catch (e) {
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> resetPassword(String email, String code, String newPassword) async {
    isLoading.value = true;
    try {
      final result = await _authService.resetPassword(email, code, newPassword);
      if (result != null) {
        user.value = result['user'];
        isLoggedIn.value = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(result['user']));
        return true;
      }
    } catch (e) {
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<bool> verifyEmail(String code) async {
    isLoading.value = true;
    try {
      final res = await _authService.verifyEmail(code);
      if (res != null) {
        user.value = res['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(res['user']));
        return true;
      }
    } catch (e) {
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  Future<void> resendVerification() async {
    isLoading.value = true;
    try {
      await _authService.resendVerification();
    } catch (_) {
      // Silently ignore — the screen already shows a resend button
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> changePassword({String? currentPassword, required String newPassword}) async {
    isLoading.value = true;
    try {
      final success = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (success) {
        return true;
      }
    } catch (e) {
      AppSnackbar.error(null, e.toString());
    } finally {
      isLoading.value = false;
    }
    return false;
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
