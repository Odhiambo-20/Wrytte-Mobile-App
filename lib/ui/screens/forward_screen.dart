import 'package:flutter/material.dart';
import 'package:wrytte/models/contact_model.dart';
import 'package:wrytte/services/contact_service.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:wrytte/components/contact_components/contact_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/ui/screens/message_screen.dart';

class ForwardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedMessages;
  final String? currentChatId; // For redirecting back after multiple forwarding

  const ForwardScreen({
    super.key,
    required this.selectedMessages,
    this.currentChatId,
  });

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _selectedContacts = {};
  Map<String, String> _selectedContactNames = {};

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
    _messageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts =
          _contacts
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

      final contacts = await _contactService.getWrytteContactsOptimized();

      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleContactSelection(String contactId, String contactName) {
    setState(() {
      if (_selectedContacts.contains(contactId)) {
        _selectedContacts.remove(contactId);
        _selectedContactNames.remove(contactId);
      } else {
        _selectedContacts.add(contactId);
        _selectedContactNames[contactId] = contactName;
      }
    });
  }

  Future<void> _forwardToContact(String contactId) async {
    try {
      final senderId = _auth.currentUser!.uid;

      // Get or create chat ID
      final chatId = await _chatService.getOrCreateChatId(senderId, contactId);

      await _chatService.forwardMessages(
        targetChatIds: [chatId],
        selectedMessages: widget.selectedMessages,
        additionalMessage: _messageController.text.trim(),
        senderId: senderId,
      );

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message forwarded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to the chat screen of the contact we forwarded to
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => MessageScreen(
                name: _selectedContactNames[contactId] ?? 'Contact',
                receiverId: contactId,
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to forward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _forwardToMultipleContacts() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final senderId = _auth.currentUser!.uid;
      final List<String> chatIds = [];

      // Get or create chat IDs for all selected contacts
      for (final contactId in _selectedContacts) {
        final chatId = await _chatService.getOrCreateChatId(
          senderId,
          contactId,
        );
        chatIds.add(chatId);
      }

      await _chatService.forwardMessages(
        targetChatIds: chatIds,
        selectedMessages: widget.selectedMessages,
        additionalMessage: _messageController.text.trim(),
        senderId: senderId,
      );

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message forwarded to ${_selectedContacts.length} ${_selectedContacts.length == 1 ? 'contact' : 'contacts'}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // For multiple forwarding, navigate back to the original chat
      if (widget.currentChatId != null) {
        // Navigate back to the message screen we came from
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.pop(context); // Close forward screen
        Navigator.pop(context); // Close message selection mode
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to forward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  Widget _sectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  void _showSelectedContactsSheet() {
    if (_selectedContacts.isEmpty) return;

    final selectedContacts =
        _contacts
            .where(
              (contact) =>
                  contact.wrytteUserId != null &&
                  _selectedContacts.contains(contact.wrytteUserId),
            )
            .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message Input Section
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Add message',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Selected Contacts List
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: selectedContacts.length,
                      itemBuilder: (context, index) {
                        final contact = selectedContacts[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image:
                                      contact.avatarUrl != null
                                          ? DecorationImage(
                                            image: NetworkImage(
                                              contact.avatarUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                          : null,
                                  color:
                                      contact.avatarUrl == null
                                          ? Colors.blue
                                          : null,
                                ),
                                child:
                                    contact.avatarUrl == null
                                        ? Center(
                                          child: Text(
                                            contact.formattedName.isNotEmpty
                                                ? contact.formattedName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        )
                                        : null,
                              ),

                              const SizedBox(width: 12),

                              // Name
                              Expanded(
                                child: Text(
                                  contact.formattedName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // Send Icon for individual contact
                              GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context); // Close bottom sheet
                                  if (contact.wrytteUserId != null) {
                                    await _forwardToContact(
                                      contact.wrytteUserId!,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.lightBlue,
                                  ),
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Forward to All Button
                  Container(
                    margin: const EdgeInsets.all(12),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottom sheet
                        _forwardToMultipleContacts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Forward to ${_selectedContacts.length} ${_selectedContacts.length == 1 ? 'contact' : 'contacts'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leadingWidth: 150,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 8),
                child: const Text(
                  'Forward to...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        title:
            _selectedContacts.isNotEmpty
                ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_selectedContacts.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
                : null,
        actions: [
          if (_selectedContacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.lightBlue),
              onPressed: _forwardToMultipleContacts,
              padding: const EdgeInsets.only(right: 8),
              constraints: const BoxConstraints(minWidth: 40),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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
                  hintText: 'Search contacts',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 30),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    )
                    : _error.isNotEmpty
                    ? Center(
                      child: Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : _filteredContacts.isEmpty
                    ? const Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView(
                      children: [
                        // Recents Section
                        _sectionHeader('Recents'),
                        ..._filteredContacts
                            .where((contact) => contact.isRecent)
                            .map(
                              (contact) => ContactItem(
                                contact: contact,
                                onTap: () {
                                  if (contact.wrytteUserId != null) {
                                    _toggleContactSelection(
                                      contact.wrytteUserId!,
                                      contact.formattedName,
                                    );
                                    _showSelectedContactsSheet();
                                  }
                                },
                                isSelectedMode: _selectedContacts.isNotEmpty,
                                isSelected:
                                    contact.wrytteUserId != null
                                        ? _selectedContacts.contains(
                                          contact.wrytteUserId,
                                        )
                                        : false,
                                showCheckbox: true,
                              ),
                            )
                            .toList(),

                        const SizedBox(height: 8),

                        // All Contacts Section
                        ..._groupByAlphabet(
                          _filteredContacts
                              .where((contact) => !contact.isRecent)
                              .toList(),
                        ).entries.map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(entry.key),
                              ...entry.value.map(
                                (contact) => ContactItem(
                                  contact: contact,
                                  onTap: () {
                                    if (contact.wrytteUserId != null) {
                                      _toggleContactSelection(
                                        contact.wrytteUserId!,
                                        contact.formattedName,
                                      );
                                      _showSelectedContactsSheet();
                                    }
                                  },
                                  isSelectedMode: _selectedContacts.isNotEmpty,
                                  isSelected:
                                      contact.wrytteUserId != null
                                          ? _selectedContacts.contains(
                                            contact.wrytteUserId,
                                          )
                                          : false,
                                  showCheckbox: true,
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
}
