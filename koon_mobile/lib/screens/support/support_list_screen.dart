import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/support_controller.dart';
import 'chat_screen.dart';

class SupportListScreen extends StatefulWidget {
  const SupportListScreen({super.key});

  @override
  State<SupportListScreen> createState() => _SupportListScreenState();
}

class _SupportListScreenState extends State<SupportListScreen> {
  final SupportController _controller = Get.find<SupportController>();
  String _activeFilter = ''; // '' for All, 'open', 'pending', 'closed'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _controller.fetchTickets(statusFilter: _activeFilter.isEmpty ? null : _activeFilter);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('support_tickets'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('', 'all'.tr()),
                  const SizedBox(width: 8),
                  _buildFilterChip('open', 'open'.tr()),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'pending'.tr()),
                  const SizedBox(width: 8),
                  _buildFilterChip('closed', 'closed'.tr()),
                ],
              ),
            ),
          ),

          // List of Tickets
          Expanded(
            child: Obx(() {
              if (_controller.isLoadingTickets.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (_controller.tickets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.support_agent_rounded, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'no_tickets_found'.tr(),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _controller.tickets.length,
                itemBuilder: (context, index) {
                  final ticket = _controller.tickets[index];
                  final status = ticket['status'] ?? 'open';
                  final bool hasBadge = ticket['user_unread'] == true;

                  Color statusColor;
                  Color statusBg;
                  switch (status) {
                    case 'open':
                      statusColor = const Color(0xFF1E88E5);
                      statusBg = const Color(0xFFE3F2FD);
                      break;
                    case 'pending':
                      statusColor = const Color(0xFFFB8C00);
                      statusBg = const Color(0xFFFFF3E0);
                      break;
                    default:
                      statusColor = const Color(0xFF43A047);
                      statusBg = const Color(0xFFE8F5E9);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                ticketId: ticket['id'],
                                ticketTitle: ticket['title'] ?? 'Ticket',
                                isClosed: status == 'closed',
                              ),
                            ),
                          ).then((_) => _loadData());
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Ticket Title
                                  Expanded(
                                    child: Text(
                                      ticket['title'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: hasBadge ? FontWeight.bold : FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status.toString().toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Description Preview
                              Text(
                                ticket['description'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              // Footer Info
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '#${ticket['id']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (hasBadge)
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 6),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: AppColors.textHint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(ticket['updated_at']),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final bool isSelected = _activeFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _activeFilter = filterKey;
          });
          _loadData();
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
