import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wrytte/components/user_avatar.dart';
import 'package:wrytte/models/user_models/user_profile_service.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'package:wrytte/services/chat/chat_local_db.dart';
import 'package:wrytte/services/user/user_profile_service.dart';
import 'package:wrytte/ui/auth/auth_entry_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  File? _pickedImageFile;
  final ImagePicker _picker = ImagePicker();

  UserProfile? _profile;

  // Tracks the current profile image URL shown in the avatar
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await UserProfileService.instance.getCurrentUserProfile();

    if (!mounted) return;

    if (profile != null) {
      // Split name into first/last — name field in Firestore is a full name
      final nameParts = profile.name.trim().split(RegExp(r'\s+'));
      _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
      _lastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _bioController.text = profile.bio;
      // Show first link in the link field for editing
      _linkController.text = profile.links.isNotEmpty ? profile.links[0] : '';
      _currentImageUrl = profile.hasProfileImage ? profile.profileImage : null;
    }

    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedImageFile = File(picked.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF23262C),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo, color: Colors.white),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.white),
                  title: const Text(
                    'Camera',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
    );
  }

  // ── Upload image to Firebase Storage and return download URL ──────────────

  Future<String?> _uploadProfileImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final ref = FirebaseStorage.instance.ref().child(
        'user_profile_images/$uid.jpg',
      );

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ── Save all changes to Firestore ─────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Not authenticated. Please log in again.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? newImageUrl = _currentImageUrl;

      // Upload new image if one was picked
      if (_pickedImageFile != null) {
        newImageUrl = await _uploadProfileImage(_pickedImageFile!);
        if (newImageUrl == null) {
          _showSnack('Failed to upload photo. Try again.', isError: true);
          setState(() => _isSaving = false);
          return;
        }
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = [
        firstName,
        lastName,
      ].where((s) => s.isNotEmpty).join(' ');
      final bio = _bioController.text.trim();
      final link = _linkController.text.trim();

      // Build updated links list — keep existing links beyond index 0,
      // replace index 0 with the edited link field
      final existingLinks = List<String>.from(_profile?.links ?? []);
      if (link.isNotEmpty) {
        if (existingLinks.isEmpty) {
          existingLinks.add(link);
        } else {
          existingLinks[0] = link;
        }
      } else {
        // Link field was cleared — remove first link
        if (existingLinks.isNotEmpty) existingLinks.removeAt(0);
      }

      final updates = <String, dynamic>{
        'name': fullName,
        'bio': bio,
        'links': existingLinks,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newImageUrl != null) 'profileImage': newImageUrl,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      // Force refresh the in-memory cache
      await UserProfileService.instance.getCurrentUserProfile(
        forceRefresh: true,
      );

      if (!mounted) return;

      setState(() {
        _currentImageUrl = newImageUrl;
        _pickedImageFile = null;
        _isSaving = false;
      });

      _showSnack('Profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Failed to save changes. Try again.', isError: true);
    }
  }

  // ── Logout — Firebase + custom backend session ────────────────────────────

  Future<void> _logout() async {
    await AuthService.instance.logout();
    UserProfileService.instance.clearCache();
    await ChatLocalDb.instance.clearAll(); // ← wipe local chat on logout
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthEntryScreen()),
        (route) => false,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFE05252) : const Color(0xFF4DA3FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 0.4,
      color: Color(0xFF3A3D44),
      indent: 16,
      endIndent: 0,
    );
  }

  // ── Input row ─────────────────────────────────────────────────────────────

  Widget _inputRow(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF6B6E75),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF08090B);
    const cardBg = Color(0xFF23262C);
    const accent = Color(0xFF4DA3FF);

    // Determine what to show in the avatar:
    // picked local file > current URL from Firestore > initials fallback
    Widget avatarWidget;
    if (_pickedImageFile != null) {
      avatarWidget = GestureDetector(
        onTap: _showImageOptions,
        child: ClipOval(
          child: Image.file(
            _pickedImageFile!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      avatarWidget = GestureDetector(
        onTap: _showImageOptions,
        child: UserAvatar(
          size: 100,
          imageUrl: _currentImageUrl,
          name: _profile?.displayName,
        ),
      );
    }

    final String formattedPhone = _profile?.phone ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4DA3FF),
                  strokeWidth: 2,
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // ── Avatar ──
                      avatarWidget,

                      const SizedBox(height: 10),

                      // ── Set new photo ──
                      GestureDetector(
                        onTap: _showImageOptions,
                        child: const Text(
                          'Set new photo',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── First name + Last name grouped ──
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _inputRow('First name', _firstNameController),
                            _divider(),
                            _inputRow('Last name', _lastNameController),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Bio ──
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: _inputRow('Bio', _bioController),
                      ),

                      const SizedBox(height: 12),

                      // ── Link ──
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: _inputRow('Link', _linkController),
                      ),

                      const SizedBox(height: 12),

                      // ── Change number / Channel / Group grouped ──
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            // Change number row — display only, no impl yet
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Change number',
                                    style: TextStyle(
                                      color: Color(0xFF6B6E75),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formattedPhone,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF6B6E75),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),

                            _divider(),

                            // Channel row — no impl yet
                            InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      'Channel',
                                      style: TextStyle(
                                        color: Color(0xFF6B6E75),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF6B6E75),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            _divider(),

                            // Group row — no impl yet
                            InkWell(
                              onTap: () {},
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      'Group',
                                      style: TextStyle(
                                        color: Color(0xFF6B6E75),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF6B6E75),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Log out ──
                      GestureDetector(
                        onTap: _logout,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Center(
                            child: Text(
                              'Log out',
                              style: TextStyle(
                                color: Color(0xFFE05252),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }
}
