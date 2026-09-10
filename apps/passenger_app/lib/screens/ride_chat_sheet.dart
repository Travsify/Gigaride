import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';

class RideChatSheet extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String driverName;

  const RideChatSheet({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<RideChatSheet> createState() => _RideChatSheetState();
}

class _RideChatSheetState extends State<RideChatSheet> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, String>> _smartQuickReplies = [
    {'icon': '🚶', 'text': "I'm coming down / coming out now"},
    {'icon': '📍', 'text': "Waiting at the estate security gate"},
    {'icon': '⏱️', 'text': "Please wait 2 minutes, on my way!"},
    {'icon': '❄️', 'text': "Please turn on the AC"},
    {'icon': '🧳', 'text': "I have luggage / bags with me"},
    {'icon': '🚪', 'text': "Security will let you into compound"},
    {'icon': '👍', 'text': "Alright, see you in a bit!"},
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
    final provider = context.read<PassengerProvider>();

    // Load persistent chat history from backend — merge with in-memory (no overwrite)
    provider.api.getChatMessages(widget.rideId).then((serverMessages) {
      if (mounted && serverMessages.isNotEmpty) {
        for (final m in serverMessages) {
          provider.addChatMessage(widget.rideId, m);
        }
        _scrollToBottom();
      }
    }).catchError((_) {});

    // Register single socket listener — reassign so only one is ever active
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
    final provider = context.read<PassengerProvider>();

    // Generate a stable local ID so the dedup check works when the server echo arrives
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    // Send via real-time socket
    provider.socket.sendChatMessage(
      rideId: widget.rideId,
      receiverId: widget.driverId,
      text: trimmed,
    );

    // Add locally WITH an id so it's not duplicated when server echo arrives
    provider.addChatMessage(widget.rideId, {
      'id': localId,
      'senderRole': 'PASSENGER',
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
    final provider = context.watch<PassengerProvider>();
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
                      widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'D',
                      style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.driverName, style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 11, color: AppConstants.successColor),
                            SizedBox(width: 4),
                            Text('Private In-App Chat • Zero Phone Leak', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppConstants.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Smart Quick Action Chips
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

            // Messages List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.textMuted, size: 40),
                          SizedBox(height: 10),
                          Text('Direct In-App Coordination', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Tap a smart preset above or send a message.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['senderRole'] == 'PASSENGER';

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? AppConstants.primaryColor : AppConstants.surfaceBg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
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

            // Input Bar
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 6,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Message driver (estate gate, luggage, etc.)...',
                          hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppConstants.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(_textCtrl.text),
                    ),
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
