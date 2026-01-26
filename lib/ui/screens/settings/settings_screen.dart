import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wrytte/ui/screens/profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // dark navy background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== AppBar Section =====
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // balance the QR icon spacing
                  const Text(
                    "Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ===== Profile Section (real data) =====
              FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 19, 18, 18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: const AssetImage(
                              'assets/images/default_avatar.jpg',
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? 'User';
                  final phone =
                      userData?['phone'] ??
                      FirebaseAuth.instance.currentUser?.phoneNumber ??
                      'N/A';
                  final profileImageUrl = userData?['profileImage']?.toString();

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 19, 18, 18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey[800],
                            backgroundImage:
                                profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                        as ImageProvider
                                    : const AssetImage(
                                      'assets/images/default_avatar.jpg',
                                    ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ===== First Card =====
              _buildSettingsCard(
                context,
                items: [
                  _SettingsItem("Cloud Storage", Icons.cloud_outlined),
                  _SettingsItem(
                    "V Face Protection",
                    Icons.verified_user_outlined,
                  ),
                  _SettingsItem("Linked Devices", Icons.laptop_mac),
                ],
              ),

              const SizedBox(height: 20),

              // ===== Second Card =====
              _buildSettingsCard(
                context,
                items: [
                  _SettingsItem("Account", Icons.account_circle_outlined),
                  _SettingsItem("Privacy", Icons.lock_outline),
                  _SettingsItem(
                    "Notification",
                    Icons.notifications_none_rounded,
                  ),
                  _SettingsItem("Appearance", Icons.color_lens_outlined),
                  _SettingsItem("Chats", Icons.chat_bubble_outline),
                  _SettingsItem("Data and Storage", Icons.storage_outlined),
                ],
              ),

              const SizedBox(height: 60), // spacing for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  // ===== Helper Widget for Cards =====
  Widget _buildSettingsCard(
    BuildContext context, {
    required List<_SettingsItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 19, 18, 18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              InkWell(
                onTap: () {}, // empty for now
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: Colors.white, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              if (index != items.length - 1)
                const Divider(
                  color: Colors.grey,
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ===== Data Holder for Settings Item =====
class _SettingsItem {
  final String title;
  final IconData icon;
  _SettingsItem(this.title, this.icon);
}
