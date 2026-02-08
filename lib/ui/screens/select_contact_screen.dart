import 'package:flutter/material.dart';
import 'package:wrytte/models/contact_model.dart';
import 'package:wrytte/services/contact_service.dart';
import 'package:wrytte/components/contact_components/contact_item.dart';
import 'package:wrytte/ui/screens/message_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final ContactService _contactService = ContactService();
  List<Contact> _wrytteContacts = [];
  List<Contact> _nonWrytteContacts = [];
  List<Contact> _filteredWrytte = [];
  List<Contact> _filteredNonWrytte = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWrytte =
          _wrytteContacts
              .where((c) => c.formattedName.toLowerCase().contains(query))
              .toList();
      _filteredNonWrytte =
          _nonWrytteContacts
              .where((c) => c.formattedName.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final wrytteContacts = await _contactService.getWrytteContactsOptimized();
      final nonWrytteContacts = await _contactService.getNonWrytteContacts();

      setState(() {
        _wrytteContacts = wrytteContacts;
        _nonWrytteContacts = nonWrytteContacts;
        _filteredWrytte = wrytteContacts;
        _filteredNonWrytte = nonWrytteContacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToMessageScreen(Contact contact) {
    if (contact.wrytteUserId != null && contact.wrytteUserId!.isNotEmpty) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => MessageScreen(
                name: contact.formattedName,
                receiverId: contact.wrytteUserId!,
                avatarUrl: contact.avatarUrl,
                isOnline: true,
              ),
        ),
      );
    }
  }

  /// GROUP CONTACTS BY FIRST LETTER
  Map<String, List<Contact>> _groupByAlphabet(List<Contact> contacts) {
    final Map<String, List<Contact>> grouped = {};
    for (final contact in contacts) {
      final letter =
          contact.formattedName.isNotEmpty
              ? contact.formattedName[0].toUpperCase()
              : '#';
      grouped.putIfAbsent(letter, () => []).add(contact);
    }
    final keys = grouped.keys.toList()..sort();
    return Map.fromEntries(keys.map((k) => MapEntry(k, grouped[k]!)));
  }

  Widget _actionItem(IconData icon, String title) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF4EA4F6), size: 28),
          title: Text(
            title,
            style: const TextStyle(color: Color(0xFF4EA4F6), fontSize: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72),
          child: const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New chat', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search name or number',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 30),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          _actionItem(Icons.group_outlined, 'New group'),
          _actionItem(Icons.person_add_outlined, 'New contact'),
          _actionItem(Icons.campaign_outlined, 'New channel'),

          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.teal),
                          SizedBox(height: 16),
                          Text(
                            'Finding your contacts on Wrytte...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : _error.isNotEmpty
                    ? Center(
                      child: Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : _filteredWrytte.isEmpty && _filteredNonWrytte.isEmpty
                    ? const Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView(
                      children: [
                        /// WRYTTE CONTACTS
                        ..._groupByAlphabet(_filteredWrytte).entries.map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(entry.key),
                              ...entry.value.map(
                                (c) => ContactItem(
                                  contact: c,
                                  onTap: () => _navigateToMessageScreen(c),
                                ),
                              ),
                            ],
                          ),
                        ),

                        /// INVITE SECTION
                        if (_filteredNonWrytte.isNotEmpty)
                          _sectionHeader('Invite to Wrytte'),

                        /// NON-WRYTTE CONTACTS
                        ..._groupByAlphabet(_filteredNonWrytte).entries.map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(entry.key),
                              ...entry.value.map(
                                (c) => ContactItem(
                                  contact: c,
                                  showInviteButton: true,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  /// SHARED HEADER STYLE (Alphabet + Invite)
  Widget _sectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF1A1A1A),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
