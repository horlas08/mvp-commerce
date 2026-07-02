import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../app/constants/api_constants.dart';
import 'auth_controller.dart';

class SupportController extends GetxController {
  final ApiService _api = ApiService();
  final AuthController _auth = Get.find<AuthController>();

  final RxList<Map<String, dynamic>> tickets = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  final RxInt unreadSupportCount = 0.obs;
  final RxInt unreadNotificationCount = 0.obs;

  final RxBool isLoadingTickets = false.obs;
  final RxBool isLoadingMessages = false.obs;
  final RxBool isLoadingNotifications = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Whenever auth login status changes to true, fetch initial counts
    ever(_auth.isLoggedIn, (bool loggedIn) {
      if (loggedIn) {
        refreshCounts();
      } else {
        clearState();
      }
    });

    if (_auth.isLoggedIn.value) {
      refreshCounts();
    }
  }

  void clearState() {
    tickets.clear();
    messages.clear();
    notifications.clear();
    unreadSupportCount.value = 0;
    unreadNotificationCount.value = 0;
  }

  Future<void> refreshCounts() async {
    if (!_auth.isLoggedIn.value) return;
    await Future.wait([
      fetchUnreadSupportCount(),
      fetchUnreadNotificationCount(),
    ]);
  }

  // ── Support Tickets ──

  Future<void> fetchTickets({String? statusFilter}) async {
    if (!_auth.isLoggedIn.value) return;
    isLoadingTickets.value = true;
    try {
      final response = await _api.dio.get(
        ApiConstants.supportTickets,
        queryParameters: statusFilter != null ? {'status': statusFilter} : null,
      );
      if (response.statusCode == 200) {
        tickets.value = List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    isLoadingTickets.value = false;
  }

  Future<bool> createTicket(String title, String description) async {
    if (!_auth.isLoggedIn.value) return false;
    try {
      final response = await _api.dio.post(
        ApiConstants.supportTickets,
        data: {'title': title, 'description': description},
      );
      if (response.statusCode == 200) {
        // Add to local list at the beginning
        tickets.insert(0, Map<String, dynamic>.from(response.data));
        refreshCounts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchUnreadSupportCount() async {
    if (!_auth.isLoggedIn.value) return;
    try {
      final response = await _api.dio.get(ApiConstants.supportUnread);
      if (response.statusCode == 200) {
        unreadSupportCount.value = response.data['count'] ?? 0;
      }
    } catch (_) {}
  }

  // ── Messages ──

  Future<void> fetchMessages(int ticketId) async {
    if (!_auth.isLoggedIn.value) return;
    isLoadingMessages.value = true;
    try {
      final response = await _api.dio.get(ApiConstants.supportMessages(ticketId));
      if (response.statusCode == 200) {
        messages.value = List<Map<String, dynamic>>.from(response.data);
        
        // Mark as read locally in the tickets list as well
        final idx = tickets.indexWhere((t) => t['id'] == ticketId);
        if (idx != -1) {
          if (tickets[idx]['user_unread'] == true) {
            tickets[idx]['user_unread'] = false;
            tickets.refresh();
            refreshCounts();
          }
        }
      }
    } catch (_) {}
    isLoadingMessages.value = false;
  }

  Future<bool> sendReply(int ticketId, String text) async {
    if (!_auth.isLoggedIn.value) return false;
    try {
      final response = await _api.dio.post(
        ApiConstants.supportMessages(ticketId),
        data: {'message': text},
      );
      if (response.statusCode == 200) {
        messages.add(Map<String, dynamic>.from(response.data));
        
        // Update ticket's status locally to reflect "open" or "pending"
        final idx = tickets.indexWhere((t) => t['id'] == ticketId);
        if (idx != -1) {
          tickets[idx]['status'] = 'open';
          tickets[idx]['updated_at'] = DateTime.now().toUtc().toIso8601String();
          tickets.refresh();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Notifications Feed ──

  Future<void> fetchNotifications() async {
    if (!_auth.isLoggedIn.value) return;
    isLoadingNotifications.value = true;
    try {
      final response = await _api.dio.get(ApiConstants.notifications);
      if (response.statusCode == 200) {
        notifications.value = List<Map<String, dynamic>>.from(response.data);
      }
    } catch (_) {}
    isLoadingNotifications.value = false;
  }

  Future<void> markNotificationAsRead(int id) async {
    if (!_auth.isLoggedIn.value) return;
    try {
      final response = await _api.dio.post(ApiConstants.notificationRead(id));
      if (response.statusCode == 200) {
        final idx = notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          notifications[idx]['is_read'] = true;
          notifications.refresh();
          refreshCounts();
        }
      }
    } catch (_) {}
  }

  Future<void> fetchUnreadNotificationCount() async {
    if (!_auth.isLoggedIn.value) return;
    try {
      final response = await _api.dio.get(ApiConstants.notificationsUnread);
      if (response.statusCode == 200) {
        unreadNotificationCount.value = response.data['count'] ?? 0;
      }
    } catch (_) {}
  }
}
