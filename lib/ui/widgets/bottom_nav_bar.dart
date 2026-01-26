import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int totalUnreadCount;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.totalUnreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color.fromARGB(255, 19, 18, 18), width: 0.1),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color.fromARGB(255, 19, 18, 18),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: currentIndex,
        onTap: onTap,
        iconSize: 28.0,
        items: [
          // Shops — using PNG now
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/svg/coin_icon.png',
              height: 28,
              width: 28,
              color: currentIndex == 0 ? Colors.white : Colors.grey,
              colorBlendMode: BlendMode.srcIn,
            ),
            label: 'Shops',
          ),

          // Chats with unread count badge
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  currentIndex == 1
                      ? 'assets/svg/chat_filled.svg'
                      : 'assets/svg/chat_icon.svg',
                  height: 28,
                  width: 28,
                  // ignore: deprecated_member_use
                  color: currentIndex == 1 ? Colors.white : Colors.grey,
                ),
                if (totalUnreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color.fromARGB(255, 19, 18, 18),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        totalUnreadCount > 99
                            ? '99+'
                            : totalUnreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Chats',
          ),

          // Post — using PNG
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/svg/posts_icon.png',
              height: 28,
              width: 28,
              color:
                  currentIndex == 2
                      ? Colors.white
                      : const Color.fromRGBO(158, 158, 158, 1),
              colorBlendMode: BlendMode.srcIn,
            ),
            label: 'Post',
          ),

          // Calls
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 3 ? Icons.call : Icons.call_outlined,
              size: 28.0,
            ),
            label: 'Calls',
          ),

          // Settings (unchanged)
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 4 ? Icons.settings : Icons.settings_outlined,
              size: 28.0,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
