import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/support_controller.dart';

class ChatScreen extends StatefulWidget {
  final int ticketId;
  final String ticketTitle;
  final bool isClosed;

  const ChatScreen({
    super.key,
    required this.ticketId,
    required this.ticketTitle,
    required this.isClosed,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupportController _controller = Get.find<SupportController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    _controller.fetchMessages(widget.ticketId).then((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    final success = await _controller.sendReply(widget.ticketId, text);
    if (success) {
      _textController.clear();
      _scrollToBottom();
    }
    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ticketTitle,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: Obx(() {
              if (_controller.isLoadingMessages.value && _controller.messages.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _controller.messages.length,
                itemBuilder: (context, index) {
                  final msg = _controller.messages[index];
                  final bool isMe = msg['sender'] == 'user';
                  final String senderName = isMe ? 'you'.tr() : 'admin'.tr();
                  final String messageText = msg['message'] ?? '';
                  final String timeStr = _formatTime(msg['created_at']);

                  // Alignment
                  final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
                  final bubbleBg = isMe ? AppColors.primary : AppColors.surfaceVariant;
                  final textColor = isMe ? Colors.white : AppColors.textPrimary;
                  final bubbleRadius = BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 2),
                    bottomRight: Radius.circular(isMe ? 2 : 16),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: alignment,
                      child: Column(
                        crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // Sender Label
                          Padding(
                            padding: const EdgeInsets.only(left: 6, right: 6, bottom: 2),
                            child: Text(
                              senderName,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Bubble Container
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bubbleBg,
                              borderRadius: bubbleRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  messageText,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textColor,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isMe ? Colors.white70 : AppColors.textHint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // Message Input Bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
              left: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: widget.isClosed
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'ticket_closed_message'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'chat_placeholder'.tr(),
                            hintStyle: const TextStyle(color: AppColors.textHint),
                            fillColor: AppColors.surfaceVariant,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send Button
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
