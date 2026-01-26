import 'package:flutter/material.dart';

class SelectionTopBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onMarkAsRead;
  final VoidCallback onPin;
  final VoidCallback onMute;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool isVisible;

  const SelectionTopBar({
    super.key,
    required this.selectedCount,
    required this.onClose,
    required this.onMarkAsRead,
    required this.onPin,
    required this.onMute,
    required this.onArchive,
    required this.onDelete,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      color: const Color.fromARGB(255, 19, 18, 18),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Arrow back button and count
              Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.lightBlue,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    selectedCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16), // Spacing before action buttons
                ],
              ),

              // Action buttons - evenly spaced (no labels, larger icons)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.mark_chat_read_outlined,
                      onTap: onMarkAsRead,
                    ),
                    _buildActionButton(
                      icon: Icons.push_pin_outlined,
                      onTap: onPin,
                    ),
                    _buildActionButton(
                      icon: Icons.volume_off_outlined,
                      onTap: onMute,
                    ),
                    _buildActionButton(
                      icon: Icons.archive_outlined,
                      onTap: onArchive,
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 26, // Larger icons
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
