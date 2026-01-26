import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wrytte/ui/auth/phone_auth_page.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  Map<String, dynamic>? _userData;
  String? _profileImageUrl; // local cached URL
  File? _pickedImageFile;
  final ImagePicker _picker = ImagePicker();

  // Links storage
  final List<String> _links = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Add listeners to detect changes
    _nameController.addListener(_checkForChanges);
    _usernameController.addListener(_checkForChanges);
    _bioController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final nameChanged = _nameController.text != (_userData?['name'] ?? '');
    final usernameChanged =
        _usernameController.text != (_userData?['username'] ?? '');
    final bioChanged = _bioController.text != (_userData?['bio'] ?? '');

    final hasChanges =
        nameChanged ||
        usernameChanged ||
        bioChanged ||
        _pickedImageFile != null;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
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
        _userData = doc.data() ?? {};
        _nameController.text = (_userData?['name'] ?? '') as String;
        _usernameController.text = (_userData?['username'] ?? '') as String;
        _bioController.text = (_userData?['bio'] ?? '') as String;

        // load links if present (expecting a List in Firestore)
        final ls = _userData?['links'];
        if (ls is List) {
          _links.clear();
          _links.addAll(ls.whereType<String>());
        }

        _profileImageUrl = (_userData?['profileImage'] ?? '') as String?;
      }
    } catch (e, st) {
      debugPrint('Error loading profile data: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() {
        _pickedImageFile = File(picked.path);
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  Future<String?> _uploadProfileImage(File file) async {
    if (_currentUser == null) return null;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('user_profile_images')
        .child('${_currentUser.uid}.jpg');

    try {
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile image')),
        );
      }
      return null;
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    if (username.trim().isEmpty) return false;
    final query =
        await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

    if (query.docs.isEmpty) return true;

    // If doc exists, allow it only if it's the current user
    final doc = query.docs.first;
    return doc.id == _currentUser?.uid;
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim();
    final newBio = _bioController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Check username uniqueness only if changed
      if (newUsername != (_userData?['username'] ?? '')) {
        final available = await _isUsernameAvailable(newUsername);
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username is already taken')),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // If a new image was picked, upload it first
      String? imageUrl = _profileImageUrl;
      if (_pickedImageFile != null) {
        final uploadedUrl = await _uploadProfileImage(_pickedImageFile!);
        if (uploadedUrl != null) imageUrl = uploadedUrl;
      }

      // Prepare update map
      final updateData = <String, dynamic>{
        'name': newName,
        'username': newUsername,
        'bio': newBio,
        'links': _links,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null && imageUrl.isNotEmpty) {
        updateData['profileImage'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .update(updateData);

      // reflect locally
      _userData = {...?_userData, ...updateData};
      _profileImageUrl = imageUrl;
      _pickedImageFile = null;
      _hasUnsavedChanges = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.of(context).pop(); // pop back to profile (good UX)
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (c) => AlertDialog(
            title: const Text('Log Out'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Log Out'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PhoneAuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(c).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(c).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_profileImageUrl != null || _pickedImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(c).pop();
                    setState(() {
                      _profileImageUrl = null;
                      _pickedImageFile = null;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(c).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddLinkDialog() async {
    final TextEditingController linkController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Add Link'),
          content: TextField(
            controller: linkController,
            decoration: const InputDecoration(hintText: 'https://example.com'),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(linkController.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _links.add(result);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _removeLinkAt(int index) {
    setState(() {
      _links.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Colors following your dark design
    const bg = Color(0xFF000000);
    const card = Color.fromARGB(255, 19, 18, 18);
    const accent = Colors.blue;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 19, 18, 18),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white),
            overflow: TextOverflow.visible,
          ),
        ),
        title: const SizedBox.shrink(),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading || !_hasUnsavedChanges ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color:
                    _isLoading || !_hasUnsavedChanges
                        ? Colors.grey
                        : Colors.lightBlue,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Avatar + "Set new photo"
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(60),
                                      onTap: _showImageSourceOptions,
                                      child: CircleAvatar(
                                        radius: 55,
                                        backgroundColor: Colors.grey[850],
                                        backgroundImage:
                                            _pickedImageFile != null
                                                ? FileImage(_pickedImageFile!)
                                                    as ImageProvider
                                                : (_profileImageUrl != null &&
                                                        _profileImageUrl!
                                                            .isNotEmpty
                                                    ? NetworkImage(
                                                      _profileImageUrl!,
                                                    )
                                                    : const AssetImage(
                                                      'assets/images/default_avatar.jpg',
                                                    )),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _showImageSourceOptions,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Set new photo',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.edit,
                                          color: accent,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Name
                            const Text(
                              'Name',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  border: InputBorder.none,
                                ),
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Please enter your name'
                                            : null,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Number + Change number (onTap blank)
                            const Text(
                              'Number',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _userData?['phone'] ??
                                          _currentUser?.phoneNumber ??
                                          'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      // Change number screen - placeholder
                                    },
                                    child: Text(
                                      'Change number',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Bio
                            const Text(
                              'Bio',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextFormField(
                                controller: _bioController,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: InputBorder.none,
                                  hintText: 'No bio yet',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Links
                            const Text(
                              'Links',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                title: const Text(
                                  'Add links',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 18,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.add,
                                  color: Colors.blue,
                                ),
                                onTap: _showAddLinkDialog,
                              ),
                            ),

                            // show added links
                            if (_links.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Column(
                                children: List.generate(_links.length, (i) {
                                  final link = _links[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: card,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        link,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeLinkAt(i),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Channels and Groups (placeholder)
                            const Text(
                              'Channels and Groups',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                title: const Text(
                                  'Add +',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 18,
                                  ),
                                ),
                                onTap: () {
                                  // add channels/groups logic later
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Add another account (placeholder)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'You can use 3 multiple accounts in your device with different numbers.',
                                style: TextStyle(color: Colors.grey[400]),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                title: const Center(
                                  child: Text(
                                    'Add another account',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  // placeholder for adding another account
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Log Out
                            Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                title: Center(
                                  child: Text(
                                    'Log Out',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                onTap: _confirmLogout,
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
