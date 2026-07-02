import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/support_controller.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final SupportController _controller = Get.find<SupportController>();

  @override
  void initState() {
    super.initState();
    _controller.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.fetchNotifications(),
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoadingNotifications.value && _controller.notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (_controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  'no_notifications'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _controller.notifications.length,
          itemBuilder: (context, index) {
            final notif = _controller.notifications[index];
            final int id = notif['id'] ?? 0;
            final bool isRead = notif['is_read'] == true;
            final String type = notif['type'] ?? '';
            final String title = notif['title'] ?? '';
            final String message = notif['message'] ?? '';
            final String timeStr = _formatTime(notif['created_at']);

            IconData iconData;
            Color iconColor;
            Color iconBg;

            switch (type) {
              case 'order_status':
                iconData = Icons.local_shipping_outlined;
                iconColor = const Color(0xFF1E88E5);
                iconBg = const Color(0xFFE3F2FD);
                break;
              case 'new_login':
                iconData = Icons.security_outlined;
                iconColor = const Color(0xFFFB8C00);
                iconBg = const Color(0xFFFFF3E0);
                break;
              default:
                iconData = Icons.support_agent_outlined;
                iconColor = const Color(0xFF43A047);
                iconBg = const Color(0xFFE8F5E9);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isRead ? AppColors.surface : AppColors.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead ? AppColors.divider : AppColors.primary.withOpacity(0.15),
                  width: isRead ? 0.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    if (!isRead) {
                      _controller.markNotificationAsRead(id);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon Container
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(iconData, size: 20, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        // Message Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
          },
        );
      }),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
