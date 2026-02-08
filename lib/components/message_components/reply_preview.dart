import 'package:flutter/material.dart';

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyingToMessage;
  final String currentUserId;
  final String otherUserName;
  final VoidCallback onCancel;
  final VoidCallback? onTapOriginal;

  const ReplyPreview({
    super.key,
    required this.replyingToMessage,
    required this.currentUserId,
    required this.otherUserName,
    required this.onCancel,
    this.onTapOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final isReplyingToOwnMessage =
        replyingToMessage['senderId'] == currentUserId;
    final senderName = isReplyingToOwnMessage ? 'You' : otherUserName;
    final messageType = replyingToMessage['messageType'] ?? 'text';

    return GestureDetector(
      onTap: onTapOriginal,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: Row(
          children: [
            // Left reply indicator
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            // Reply content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Show different content based on message type
                  if (messageType == 'text')
                    _buildTextPreview(replyingToMessage['text'] ?? '')
                  else if (messageType == 'audio')
                    _buildAudioPreview(replyingToMessage['audioDuration'])
                  else if (messageType == 'image')
                    _buildImagePreview(),
                ],
              ),
            ),

            // Cancel button
            IconButton(
              onPressed: onCancel,
              icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPreview(String messageText) {
    return Text(
      messageText.length > 60
          ? '${messageText.substring(0, 60)}…'
          : messageText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
    );
  }

  Widget _buildAudioPreview(Duration? audioDuration) {
    // Format duration to MM:SS format
    String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$minutes:$seconds';
    }

    final durationText =
        audioDuration != null ? '(${formatDuration(audioDuration)})' : '';

    return Row(
      children: [
        Icon(Icons.mic, color: Colors.grey.shade400, size: 16),
        const SizedBox(width: 6),
        Text(
          'Voice message $durationText',
          style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    // Check if there's an image URL in the message
    final imageUrl = replyingToMessage['imageUrl'];

    return Row(
      children: [
        Icon(Icons.image, color: Colors.grey.shade400, size: 16),
        const SizedBox(width: 6),
        if (imageUrl != null && imageUrl.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                Text(
                  'Photo',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                ),
                const SizedBox(width: 8),
                // Small image preview
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'Photo',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
      ],
    );
  }
}
