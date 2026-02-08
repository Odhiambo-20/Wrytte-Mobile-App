import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clipboard/clipboard.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .get();

      if (doc.exists) {
        setState(() => _userData = doc.data());
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPhoneMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: const Text(
                    'Copy number',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    final phone =
                        _userData?['phone'] ?? _currentUser?.phoneNumber ?? '';
                    if (phone.isNotEmpty) {
                      FlutterClipboard.copy(phone).then((_) {
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Number copied')),
                        );
                      });
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No number to copy')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text(
                    'Change number',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to change number screen
                  },
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.blue),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _launchUrl(String url) async {
    Uri uri;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      uri = Uri.parse('https://$url');
    } else {
      uri = Uri.parse(url);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  Widget _buildInfoCard() {
    final bio = _userData?['bio']?.toString() ?? '';
    final links =
        _userData?['links'] is List
            ? List<String>.from(_userData!['links'])
            : <String>[];

    final hasBio = bio.isNotEmpty;
    final hasLinks = links.isNotEmpty;
    final hasContent = hasBio || hasLinks;

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2C34),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F2C34), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bio Section
            if (hasBio) ...[
              const Text(
                'Bio',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                bio,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (hasLinks) const SizedBox(height: 8),
            ],

            // Links Section
            if (hasLinks) ...[
              const Text(
                'Links',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Column(
                children:
                    links.map((link) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: () => _launchUrl(link),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  link,
                                  style: const TextStyle(
                                    color: Colors.lightBlue,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.open_in_new,
                                color: Colors.lightBlue,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _userData?['phone'] ?? _currentUser?.phoneNumber ?? 'N/A';
    final name = _userData?['name'] ?? 'John Doe';
    final profileImageUrl = _userData?['profileImage']?.toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 19, 18, 18),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ).then((_) => _loadUserData()); // Refresh on return
            },
            child: const Text(
              'Edit',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _userData == null
              ? const Center(
                child: Text(
                  'Error loading profile',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // AVATAR
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 64,
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
                      ),
                    ),

                    const SizedBox(height: 16),

                    // NAME
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // PHONE NUMBER (TAPPABLE)
                    GestureDetector(
                      onTap: _showPhoneMenu,
                      child: Text(
                        '$phone',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    //  INFO CARD (Dynamic Content)
                    _buildInfoCard(),

                    const SizedBox(height: 25),

                    //  HIGHLIGHTS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Highlights',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Divider(color: Colors.grey[700], thickness: 1),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ADD STORIE BUTTON
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Navigate to add story
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Add Storie coming soon!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Storie',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }
}
