import 'package:flutter/material.dart';
import 'package:wrytte/components/user_avatar.dart';

class MessageScreenAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final VoidCallback onBackPressed;
  final VoidCallback onVideoCallPressed;
  final VoidCallback onVoiceCallPressed;

  const MessageScreenAppBar({
    super.key,
    required this.name,
    required this.onBackPressed,
    required this.onVideoCallPressed,
    required this.onVoiceCallPressed,
    this.avatarUrl,
    this.isOnline = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 19, 18, 18),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPressed,
      ),
      title: Row(
        children: [
          UserAvatar(size: 40, imageUrl: avatarUrl, name: name),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  isOnline ? "Online" : "Offline",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: Colors.white),
          onPressed: onVideoCallPressed,
        ),
        const SizedBox(width: 1),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: onVoiceCallPressed,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
