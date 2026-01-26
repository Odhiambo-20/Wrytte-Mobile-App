import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddProfilePage extends StatefulWidget {
  const AddProfilePage({super.key});

  @override
  State<AddProfilePage> createState() => _AddProfilePageState();
}

class _AddProfilePageState extends State<AddProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<String> _generateUsername(String name) async {
    String base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '.');

    String username = base;
    int counter = 1;

    bool exists = await _checkIfUsernameExists(username);
    while (exists) {
      username = "$base$counter";
      counter++;
      exists = await _checkIfUsernameExists(username);
    }

    return username;
  }

  Future<bool> _checkIfUsernameExists(String username) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection("users")
              .where("username", isEqualTo: username)
              .limit(1)
              .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // If there's a permissions error, assume username doesn't exist
      // to allow the process to continue
      return false;
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter your name")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = await _generateUsername(name);

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "phone": user.phoneNumber ?? "",
        "name": name,
        "username": username,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, "/homepage");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      // ignore: avoid_print
      print("Firestore error: $e"); // For debugging
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Enter your name to get started",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Your name",
                border: OutlineInputBorder(),
                hintText: "John Doe",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Profile"),
            ),
          ],
        ),
      ),
    );
  }
}
