import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wrytte/ui/screens/chats/widgets/selection_top_bar.dart';
import 'package:wrytte/ui/screens/select_contact_screen.dart';

class TopBar extends StatelessWidget {
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

    return Container(
      color: const Color.fromARGB(255, 19, 18, 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onEditPressed,
              child: const Icon(Icons.edit, color: Colors.lightBlue, size: 25),
            ),
            Row(
              children: [
                const SizedBox(width: 40),
                IconButton(
                  onPressed: () {},
                  icon: SvgPicture.asset(
                    'assets/svg/stories_icon.svg',
                    height: 25,
                    width: 25,
                    // ignore: deprecated_member_use
                    color: Colors.lightBlue,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.lightBlue,
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
