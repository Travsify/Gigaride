import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';

class DriverChatSheet extends StatefulWidget {
  final String rideId;
  final String passengerId;
  final String passengerName;

  const DriverChatSheet({
    super.key,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<DriverChatSheet> createState() => _DriverChatSheetState();
}

class _DriverChatSheetState extends State<DriverChatSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, String>> _smartQuickReplies = [
    {'icon': '📍', 'text': "I'm at the pickup point / gate"},
    {'icon': '🚗', 'text': "I'm outside in the car"},
    {'icon': '🚦', 'text': "In traffic, arriving in 3 mins"},
    {'icon': '🔑', 'text': "What is the estate gate code?"},
    {'icon': '🧳', 'text': "I've popped the trunk / boot"},
    {'icon': '⏱️', 'text': "Free wait time is 3 minutes"},
    {'icon': '👍', 'text': "Understood, waiting for you!"},
  ];

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriverProvider>();

    // Load persistent chat history from backend — merge with in-memory (no overwrite)
    provider.api.getChatMessages(widget.rideId).then((serverMessages) {
      if (mounted && serverMessages.isNotEmpty) {
        for (final m in serverMessages) {
          provider.addChatMessage(widget.rideId, m);
        }
        _scrollToBottom();
      }
    }).catchError((_) {});

    // Register single socket listener — ALWAYS reassign so only one is active
    provider.socket.onChatMessage = (data) {
      provider.addChatMessage(widget.rideId, data);
      HapticFeedback.lightImpact();
      if (mounted) _scrollToBottom();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    HapticFeedback.lightImpact();
    final provider = context.read<DriverProvider>();

    // Generate a stable local ID so the dedup check works when the server echo arrives
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    // Send via real-time socket
    provider.socket.sendChatMessage(
      rideId: widget.rideId,
      receiverId: widget.passengerId,
      text: trimmed,
    );

    // Add locally WITH an id so it's not duplicated when server echo arrives
    provider.addChatMessage(widget.rideId, {
      'id': localId,
      'senderRole': 'DRIVER',
      'text': trimmed,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _textCtrl.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final messages = provider.getChatMessages(widget.rideId);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppConstants.primaryColor.withOpacity(0.3),
                    child: Text(
                      widget.passengerName.isNotEmpty ? widget.passengerName[0].toUpperCase() : 'P',
                      style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.passengerName, style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 11, color: AppConstants.successColor),
                            SizedBox(width: 4),
                            Text('Encrypted In-App Chat', style: TextStyle(color: AppConstants.successColor, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppConstants.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Smart Quick Reply Action Chips
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _smartQuickReplies.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final chip = _smartQuickReplies[i];
                  return ActionChip(
                    avatar: Text(chip['icon'] ?? '💬', style: const TextStyle(fontSize: 13)),
                    label: Text(chip['text'] ?? '', style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w500)),
                    backgroundColor: AppConstants.surfaceBg,
                    side: BorderSide(color: AppConstants.primaryLight.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () => _sendMessage(chip['text'] ?? ''),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Messages list
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 8),
                          const Text('Send a message or tap a quick chip above', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMe = msg['senderRole'] == 'DRIVER';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                            decoration: BoxDecoration(
                              color: isMe ? AppConstants.primaryColor : AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTime(msg['timestamp']),
                                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all_rounded, size: 13, color: AppConstants.accentColor),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Input bar
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type message to passenger...',
                        hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppConstants.surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_textCtrl.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
