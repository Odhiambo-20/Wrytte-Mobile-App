// lib/components/call_item.dart

import 'package:flutter/material.dart';
import 'package:wrytte/components/user_avatar.dart';

enum CallType { incoming, outgoing, missed }

class CallItem extends StatelessWidget {
  final String name;
  final String time;
  final String? avatarUrl;
  final CallType callType;
  final bool multipleCalls; // true if (2), (3) etc
  final int callCount;
  final VoidCallback? onCallPressed;
  final VoidCallback? onTap;

  const CallItem({
    super.key,
    required this.name,
    required this.time,
    this.avatarUrl,
    required this.callType,
    this.multipleCalls = false,
    this.callCount = 1,
    this.onCallPressed,
    this.onTap,
  });

  Color _getArrowColor() {
    switch (callType) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.green;
      case CallType.missed:
        return Colors.red;
    }
  }

  IconData _getArrowIcon() {
    switch (callType) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            UserAvatar(size: 60, imageUrl: avatarUrl, name: ''),
            const SizedBox(width: 12),

            // Name + call details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caller name
                  Text(
                    multipleCalls ? "$name ($callCount)" : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color:
                          callType == CallType.missed
                              ? Colors.red
                              : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Call direction + time
                  Row(
                    children: [
                      Icon(_getArrowIcon(), color: _getArrowColor(), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Divider
                  Divider(
                    // ignore: deprecated_member_use
                    color: Colors.grey.withOpacity(0.3),
                    thickness: 0.5,
                    height: 0,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Call button
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.white),
              onPressed: onCallPressed,
            ),
          ],
        ),
      ),
    );
  }
}
