import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wrytte/ui/screens/chats/widgets/selection_top_bar.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback? onEditPressed;
  final VoidCallback? onSelectionClose;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onPin;
  final VoidCallback? onMute;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const TopBar({
    super.key,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.onEditPressed,
    this.onSelectionClose,
    this.onMarkAsRead,
    this.onPin,
    this.onMute,
    this.onArchive,
    this.onDelete,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode) {
      return SelectionTopBar(
        selectedCount: selectedCount,
        onClose: onSelectionClose ?? () {},
        onMarkAsRead: onMarkAsRead ?? () {},
        onPin: onPin ?? () {},
        onMute: onMute ?? () {},
        onArchive: onArchive ?? () {},
        onDelete: onDelete ?? () {},
      );
    }

    return AppBar(
      backgroundColor: const Color(0xFF0F1013),
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: onEditPressed,
              child: const Icon(Icons.edit, color: Color(0xFF4DA3FF), size: 25),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: SvgPicture.asset(
                'assets/svg/stories_icon.svg',
                height: 25,
                width: 25,
                color: Color(0xFF4DA3FF),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF4DA3FF),
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
