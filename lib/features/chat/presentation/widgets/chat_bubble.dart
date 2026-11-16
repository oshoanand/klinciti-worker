import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/chat_message_model.dart';
import 'full_screen_image_viewer.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const ChatBubble({super.key, required this.message, required this.isMe});

  Widget _buildStatusIcon() {
    if (message.isFailed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 15,
        color: Color(0xFFFCA5A5),
      );
    }
    if (message.isSending) {
      return const Icon(
        Icons.access_time_rounded,
        size: 13,
        color: Colors.white70,
      );
    }
    return Icon(
      message.isRead ? Icons.done_all_rounded : Icons.check_rounded,
      size: 15,
      color: message.isRead ? Colors.lightBlueAccent.shade100 : Colors.white70,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = (DateTime.tryParse(message.createdAt) ?? DateTime.now())
        .toLocal();
    final timeFormat = DateFormat('HH:mm').format(parsedDate);

    final hasImage =
        message.imageUrl != null && message.imageUrl!.trim().isNotEmpty;
    final hasText = message.text != null && message.text!.trim().isNotEmpty;

    final bubbleColor = message.isFailed
        ? Colors.red.shade700
        : (isMe ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: message.isSending ? 0.75 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          constraints: BoxConstraints(
            // ✅ FIXED: Restored multiplication operator `* 0.75`
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Padding(
                  padding: EdgeInsets.only(bottom: hasText ? 8.0 : 4.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(
                            imageUrl: message.imageUrl!,
                            heroTag: message.id,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: message.id,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: message.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 160,
                            width: 180,
                            color: Colors.black12,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 150,
                            width: 160,
                            color: Colors.black12,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasText)
                Text(
                  message.text!,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.isFailed
                        ? 'Не отправлено • $timeFormat'
                        : timeFormat,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon()],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
