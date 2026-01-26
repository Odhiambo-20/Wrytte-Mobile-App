import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageMessageBubble extends StatelessWidget {
  final String imageUrl;
  final String time;
  final bool isMe;
  final bool isRead;
  final double aspectRatio;
  final VoidCallback? onTap;
  final Map<String, dynamic>? replyData;

  const ImageMessageBubble({
    super.key,
    required this.imageUrl,
    required this.time,
    required this.isMe,
    this.isRead = false,
    this.aspectRatio = 4 / 3,
    this.onTap,
    this.replyData,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Reply preview if exists
            if (replyData != null) ...[
              _buildReplyPreview(),
              const SizedBox(height: 8),
            ],

            // Image container
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        isMe
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                    bottomRight:
                        isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                        isMe
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                    bottomRight:
                        isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Image
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: MediaQuery.of(context).size.width * 0.65,
                        height:
                            (MediaQuery.of(context).size.width * 0.65) /
                            aspectRatio,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.error,
                                color: Colors.white,
                              ),
                            ),
                      ),

                      // Gradient overlay for better text visibility
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Time and status
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 12,
                                color:
                                    isRead
                                        ? Colors.blue
                                        : Colors.white.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final replyText = replyData?['replyToText'] ?? '';
    final senderName = replyData?['replyToSenderName'] ?? 'User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: isMe ? Colors.white : Colors.blue, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyText.length > 100
                ? '${replyText.substring(0, 100)}...'
                : replyText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
