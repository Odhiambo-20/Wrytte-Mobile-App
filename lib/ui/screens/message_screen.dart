import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wrytte/components/message_components/advanced_media_picker.dart';
import 'package:wrytte/components/message_components/message_bubble.dart';
import 'package:wrytte/components/message_components/message_input_field.dart';
import 'package:wrytte/components/message_components/reply_preview.dart';
import 'package:wrytte/components/message_components/emoji_picker_widget.dart';
import 'package:wrytte/components/message_components/voice_recorder_widget.dart';
import 'package:wrytte/components/message_components/message_screen_app_bar.dart';
import 'package:wrytte/services/call_service.dart';
import 'package:wrytte/services/chat_service.dart';
import 'package:wrytte/ui/screens/calls/voice_call_screen.dart';
import 'package:wrytte/ui/screens/chats/widgets/pinned_message_widget.dart';
import 'package:wrytte/ui/screens/chats/widgets/selected_message_app_bar.dart';
import 'package:wrytte/ui/screens/forward_screen.dart';

class MessageScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final String receiverId;
  final String? chatId;

  const MessageScreen({
    super.key,
    required this.name,
    required this.receiverId,
    this.avatarUrl,
    this.chatId,
    this.isOnline = false,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  Timer? _highlightTimer;

  String? _currentChatId;
  Stream<QuerySnapshot>? _messagesStream;
  Stream<DocumentSnapshot?>? _pinnedMessageStream;
  bool _isLoading = true;
  bool _hasMessages = false;
  bool _isSending = false;

  Map<String, dynamic>? _replyingToMessage;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _showEmojiPicker = false;
  bool _showVoiceRecorder = false;

  // Message selection state
  Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false;
  bool _hasSenderMessagesSelected = false;
  bool _hasReceiverMessagesSelected = false;
  Map<String, Map<String, dynamic>> _selectedMessagesData = {};

  // Pinned message state
  DocumentSnapshot? _pinnedMessage;

  // Track if we should scroll to bottom
  bool _shouldScrollToBottom = true;

  // Editing state
  String? _editingMessageId;
  Map<String, dynamic>? _editingMessageData;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      print('Initializing chat with receiver: ${widget.receiverId}');

      final chatId = await _chatService.getOrCreateChatId(
        _auth.currentUser!.uid,
        widget.receiverId,
      );

      print('Chat ID created/retrieved: $chatId');

      setState(() {
        _currentChatId = chatId;
        _messagesStream = _chatService.getMessages(chatId);
        _pinnedMessageStream = _chatService.getPinnedMessageStream(chatId);
        _isLoading = false;
      });

      await _chatService.markMessagesAsRead(chatId, _auth.currentUser!.uid);
      print('Messages marked as read');
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final messageText = _controller.text.trim();

    try {
      // Get or create chat ID - THIS WILL AUTO-RESTORE IF DELETED
      final chatId = await _chatService.getOrCreateChatId(
        _auth.currentUser!.uid,
        widget.receiverId,
      );

      // Update current chat ID
      setState(() {
        _currentChatId = chatId;
      });

      // Set up messages stream if not already
      if (_messagesStream == null) {
        setState(() {
          _messagesStream = _chatService.getMessages(chatId);
          _pinnedMessageStream = _chatService.getPinnedMessageStream(chatId);
        });
      }

      final Map<String, dynamic>? replyData =
          _replyingToMessage != null
              ? {
                'replyToMessageId': _replyingToMessage!['id'],
                'replyToText': _replyingToMessage!['text'],
                'replyToSenderId': _replyingToMessage!['senderId'],
                'replyToSenderName':
                    _replyingToMessage!['senderId'] == _auth.currentUser!.uid
                        ? 'You'
                        : widget.name,
                'replyToMessageType':
                    _replyingToMessage!['messageType'] ?? 'text',
              }
              : null;

      await _chatService.sendMessage(
        chatId, // Use the newly obtained chatId
        messageText,
        _auth.currentUser!.uid,
        widget.receiverId,
        replyData: replyData,
      );

      print(' Message sent successfully to chat: $chatId');

      if (_replyingToMessage != null) {
        _cancelReply();
      }

      _controller.clear();
      _scrollToBottom();

      // Mark messages as read after sending
      await _chatService.markMessagesAsRead(chatId, _auth.currentUser!.uid);
    } catch (e) {
      print(' Error sending message: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      _controller.text = messageText;
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Image handling methods
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1440,
      );

      if (image != null) {
        final File imageFile = File(image.path);

        //Get or create chat ID - THIS WILL AUTO-RESTORE IF DELETED
        final chatId = await _chatService.getOrCreateChatId(
          _auth.currentUser!.uid,
          widget.receiverId,
        );

        // Update current chat ID
        setState(() {
          _currentChatId = chatId;
        });

        // Set up messages stream if not already set
        if (_messagesStream == null) {
          setState(() {
            _messagesStream = _chatService.getMessages(chatId);
            _pinnedMessageStream = _chatService.getPinnedMessageStream(chatId);
          });
        }

        final Map<String, dynamic>? replyData =
            _replyingToMessage != null
                ? {
                  'replyToMessageId': _replyingToMessage!['id'],
                  'replyToText': _replyingToMessage!['text'] ?? 'Photo',
                  'replyToSenderId': _replyingToMessage!['senderId'],
                  'replyToSenderName':
                      _replyingToMessage!['senderId'] == _auth.currentUser!.uid
                          ? 'You'
                          : widget.name,
                  'replyToMessageType':
                      _replyingToMessage!['messageType'] ?? 'text',
                }
                : null;

        await _chatService.sendImageMessage(
          chatId, // Use the newly obtained chatId
          imageFile,
          _auth.currentUser!.uid,
          widget.receiverId,
          replyData: replyData,
        );

        if (_replyingToMessage != null) {
          _cancelReply();
        }

        _scrollToBottom();

        // Mark messages as read after sending
        await _chatService.markMessagesAsRead(chatId, _auth.currentUser!.uid);
      }
    } catch (e) {
      print(' Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Voice message handling
  Future<void> _sendVoiceMessage(String audioPath) async {
    try {
      final File audioFile = File(audioPath);
      final Duration duration = Duration.zero;

      // Get or create chat ID - THIS WILL AUTO-RESTORE IF DELETED
      final chatId = await _chatService.getOrCreateChatId(
        _auth.currentUser!.uid,
        widget.receiverId,
      );

      // Update current chat ID
      setState(() {
        _currentChatId = chatId;
      });

      // Set up messages stream if not already set
      if (_messagesStream == null) {
        setState(() {
          _messagesStream = _chatService.getMessages(chatId);
          _pinnedMessageStream = _chatService.getPinnedMessageStream(chatId);
        });
      }

      final Map<String, dynamic>? replyData =
          _replyingToMessage != null
              ? {
                'replyToMessageId': _replyingToMessage!['id'],
                'replyToText': 'Voice message',
                'replyToSenderId': _replyingToMessage!['senderId'],
                'replyToSenderName':
                    _replyingToMessage!['senderId'] == _auth.currentUser!.uid
                        ? 'You'
                        : widget.name,
                'replyToMessageType':
                    _replyingToMessage!['messageType'] ?? 'text',
              }
              : null;

      await _chatService.sendVoiceMessage(
        chatId, // Use the newly obtained chatId
        audioFile,
        _auth.currentUser!.uid,
        widget.receiverId,
        duration,
        replyData: replyData,
      );

      if (_replyingToMessage != null) {
        _cancelReply();
      }

      _scrollToBottom();

      // Mark messages as read after sending
      await _chatService.markMessagesAsRead(chatId, _auth.currentUser!.uid);
    } catch (e) {
      print(' Error sending voice message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Attachment handling
  void _showMediaPicker() {
    _hideEmojiPicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => AdvancedMediaPicker(
            onImageSelected: (imageFile) async {
              try {
                final chatId = await _chatService.getOrCreateChatId(
                  _auth.currentUser!.uid,
                  widget.receiverId,
                );

                setState(() {
                  _currentChatId = chatId;
                });

                if (_messagesStream == null) {
                  setState(() {
                    _messagesStream = _chatService.getMessages(chatId);
                    _pinnedMessageStream = _chatService.getPinnedMessageStream(
                      chatId,
                    );
                  });
                }

                final Map<String, dynamic>? replyData =
                    _replyingToMessage != null
                        ? {
                          'replyToMessageId': _replyingToMessage!['id'],
                          'replyToText': _replyingToMessage!['text'] ?? 'Photo',
                          'replyToSenderId': _replyingToMessage!['senderId'],
                          'replyToSenderName':
                              _replyingToMessage!['senderId'] ==
                                      _auth.currentUser!.uid
                                  ? 'You'
                                  : widget.name,
                          'replyToMessageType':
                              _replyingToMessage!['messageType'] ?? 'text',
                        }
                        : null;

                await _chatService.sendImageMessage(
                  chatId,
                  imageFile,
                  _auth.currentUser!.uid,
                  widget.receiverId,
                  replyData: replyData,
                );

                if (_replyingToMessage != null) {
                  _cancelReply();
                }

                _scrollToBottom();
                await _chatService.markMessagesAsRead(
                  chatId,
                  _auth.currentUser!.uid,
                );
              } catch (e) {
                print(' Error sending image: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send image: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            onDocumentPressed: () {
              // TODO: Implement document picker
              print('Document picker pressed');
            },
            onLocationPressed: () {
              // TODO: Implement location sharing
              print('Location sharing pressed');
            },
            onContactPressed: () {
              // TODO: Implement contact sharing
              print('Contact sharing pressed');
            },
            onAudioPressed: () {
              // TODO: Implement audio picker
              print('Audio picker pressed');
            },
            onPollPressed: () {
              // TODO: Implement poll creation
              print('Poll creation pressed');
            },
          ),
    );
  }

  // Emoji handling
  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _hideEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
  }

  // Voice recorder handling
  void _toggleVoiceRecorder() {
    setState(() {
      _showVoiceRecorder = !_showVoiceRecorder;
    });
  }

  // Reply functionality methods
  void _setReplyingToMessage(Map<String, dynamic> message) {
    setState(() {
      _replyingToMessage = message;
    });

    _hideEmojiPicker();
    FocusScope.of(context).requestFocus(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      _scrollToBottom();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  // Cancel editing
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _editingMessageData = null;
      _controller.clear();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _highlightMessage(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });

    _scrollToMessage(messageId);

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _scrollToMessage(String messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[messageId];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Message selection methods
  void _toggleMessageSelection(
    String messageId,
    bool isSenderMessage,
    Map<String, dynamic> messageData,
  ) {
    // Prevent auto-scroll when selecting messages
    setState(() {
      _shouldScrollToBottom = false;
    });

    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        _selectedMessagesData.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
        _selectedMessagesData[messageId] = messageData;
        if (isSenderMessage) {
          _hasSenderMessagesSelected = true;
        } else {
          _hasReceiverMessagesSelected = true;
        }
      }

      // Update selection flags
      if (_selectedMessageIds.isEmpty) {
        _isSelectionMode = false;
        _hasSenderMessagesSelected = false;
        _hasReceiverMessagesSelected = false;
        _selectedMessagesData.clear();

        // Re-enable auto-scroll when selection is cleared
        _shouldScrollToBottom = true;
      } else {
        _isSelectionMode = true;

        // Re-check flags
        bool hasSender = false;
        bool hasReceiver = false;
        for (final id in _selectedMessageIds) {
          final data = _selectedMessagesData[id];
          if (data?['senderId'] == _auth.currentUser!.uid) {
            hasSender = true;
          } else {
            hasReceiver = true;
          }
        }
        _hasSenderMessagesSelected = hasSender;
        _hasReceiverMessagesSelected = hasReceiver;
      }
    });
  }

  void _enterSelectionMode(
    String firstMessageId,
    bool isSenderMessage,
    Map<String, dynamic> messageData,
  ) {
    // Prevent auto-scroll when entering selection mode
    setState(() {
      _shouldScrollToBottom = false;
    });

    setState(() {
      _selectedMessageIds.add(firstMessageId);
      _selectedMessagesData[firstMessageId] = messageData;
      _isSelectionMode = true;
      if (isSenderMessage) {
        _hasSenderMessagesSelected = true;
      } else {
        _hasReceiverMessagesSelected = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _selectedMessagesData.clear();
      _isSelectionMode = false;
      _hasSenderMessagesSelected = false;
      _hasReceiverMessagesSelected = false;

      // Re-enable auto-scroll when selection is cleared
      _shouldScrollToBottom = true;
    });
  }

  // Message action methods
  void _handleReplyAction() {
    if (_selectedMessageIds.isNotEmpty) {
      final firstMessageId = _selectedMessageIds.first;
      final messageData = _selectedMessagesData[firstMessageId];
      if (messageData != null) {
        _setReplyingToMessage({
          'id': firstMessageId,
          'text': messageData['text'] ?? '',
          'senderId': messageData['senderId'] ?? '',
          'timestamp': messageData['timestamp'],
          'messageType': messageData['messageType'] ?? 'text',
        });
      }
      _clearSelection();
    }
  }

  // Handle edit action
  void _handleEditAction() {
    if (_selectedMessageIds.isNotEmpty) {
      final messageId = _selectedMessageIds.first;
      final messageData = _selectedMessagesData[messageId];
      if (messageData != null) {
        setState(() {
          _editingMessageId = messageId;
          _editingMessageData = messageData;
          _controller.text = messageData['text'] ?? '';
        });
        _clearSelection();
      }
    }
  }

  // Save edited message
  void _saveEditedMessage() async {
    if (_editingMessageId == null ||
        _controller.text.trim().isEmpty ||
        _currentChatId == null) {
      return;
    }

    try {
      await _chatService.editMessage(
        _currentChatId!,
        _editingMessageId!,
        _controller.text.trim(),
        _auth.currentUser!.uid,
      );

      setState(() {
        _editingMessageId = null;
        _editingMessageData = null;
      });

      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message edited'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to edit message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleCopyAction() {
    if (_selectedMessageIds.isNotEmpty) {
      final messageData = _selectedMessagesData[_selectedMessageIds.first];
      if (messageData != null) {
        final text = messageData['text'] ?? '';
        if (text.isNotEmpty) {
          // TODO: Implement copy to clipboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      _clearSelection();
    }
  }

  void _handlePinAction() {
    if (_selectedMessageIds.isNotEmpty && _currentChatId != null) {
      final messageId = _selectedMessageIds.first;
      _chatService.pinMessage(
        _currentChatId!,
        messageId,
        _auth.currentUser!.uid,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message pinned'),
          backgroundColor: Colors.green,
        ),
      );
      _clearSelection();
    }
  }

  void _handleUnpinAction() {
    if (_pinnedMessage != null && _currentChatId != null) {
      _chatService.unpinMessage(_currentChatId!, _pinnedMessage!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message unpinned'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleForwardAction() {
    if (_selectedMessageIds.isNotEmpty) {
      final selectedMessages = _selectedMessagesData.values.toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ForwardScreen(selectedMessages: selectedMessages),
        ),
      );
    }
  }

  void _handleDeleteAction() {
    _showDeleteDialog();
  }

  // Delete dialog
  void _showDeleteDialog() {
    final hasOnlyReceiverMessages =
        _hasReceiverMessagesSelected && !_hasSenderMessagesSelected;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Delete message',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              if (!hasOnlyReceiverMessages)
                TextButton(
                  onPressed: () {
                    // Delete for everyone
                    _deleteMessages(true);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Delete for everyone',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: () {
                  // Delete for me
                  _deleteMessages(false);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete for me',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.lightBlue),
                ),
              ),
            ],
          ),
    );
  }

  // Delete messages
  void _deleteMessages(bool forEveryone) async {
    try {
      if (_currentChatId == null) return;

      for (final messageId in _selectedMessageIds) {
        await _chatService.deleteMessage(
          _currentChatId!,
          messageId,
          _auth.currentUser!.uid,
          forEveryone,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedMessageIds.length} message(s) deleted'),
          backgroundColor: Colors.green,
        ),
      );

      _clearSelection();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete messages: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Voice call initiation
  void _initiateVoiceCall() async {
    try {
      final callService = CallService();
      final currentUser = _auth.currentUser!;

      final callId = await callService.initiateCall(
        callerId: currentUser.uid,
        callerName: 'You',
        callerAvatar: '',
        receiverId: widget.receiverId,
        receiverName: widget.name,
        receiverAvatar: widget.avatarUrl ?? '',
        isVideoCall: false,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => VoiceCallScreen(
                receiverId: widget.receiverId,
                receiverName: widget.name,
                receiverAvatar: widget.avatarUrl ?? '',
                callId: callId,
                isIncomingCall: false,
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // date formatting
  String _formatDateHeader(DateTime messageTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(
      messageTime.year,
      messageTime.month,
      messageTime.day,
    );

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${messageTime.day} ${months[messageTime.month - 1]} ${messageTime.year}';
    }
  }

  String _formatMessageTime(DateTime messageTime) {
    return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
  }

  Map<String, List<QueryDocumentSnapshot>> _groupMessagesByDate(
    List<QueryDocumentSnapshot> messages,
  ) {
    final groupedMessages = <String, List<QueryDocumentSnapshot>>{};

    for (final message in messages) {
      final messageData = message.data() as Map<String, dynamic>;
      final timestamp = messageData['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final messageTime = timestamp.toDate();
        final dateKey = _formatDateHeader(messageTime);

        if (!groupedMessages.containsKey(dateKey)) {
          groupedMessages[dateKey] = [];
        }
        groupedMessages[dateKey]!.add(message);
      }
    }

    return groupedMessages;
  }

  Widget _buildDateHeader(String date) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          date,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptionNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[800]?.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey[600]!, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.grey, size: 24),
              const SizedBox(height: 12),
              Text(
                "Messages and calls are end-to-end encrypted",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Only people in this chat can read, listen to, or share them.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  print('Learn more tapped');
                },
                child: Text(
                  "Learn more",
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(QuerySnapshot? snapshot) {
    final messages = snapshot?.docs ?? [];

    print('Building message list with ${messages.length} messages');

    if (messages.isNotEmpty && !_hasMessages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasMessages = true;
          });
        }
      });
    } else if (messages.isEmpty && _hasMessages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasMessages = false;
          });
        }
      });
    }

    // Only scroll to bottom if we should
    if (_shouldScrollToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    final groupedMessages = _groupMessagesByDate(messages);

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/chat_wallpaper.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          ListView.builder(
            key: _listKey,
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 50, bottom: 8),
            itemCount: _calculateTotalItemCount(groupedMessages),
            itemBuilder: (context, index) {
              return _buildMessageItem(index, groupedMessages);
            },
          ),

          // Pinned message widget at top
          if (_pinnedMessage != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: PinnedMessageWidget(
                pinnedMessageDoc: _pinnedMessage,
                onTap: () {
                  _onPinnedMessageTap();
                },
                currentUserId: _auth.currentUser!.uid,
                otherUserName: widget.name,
              ),
            ),
        ],
      ),
    );
  }

  void _onPinnedMessageTap() {
    if (_pinnedMessage != null) {
      final messageData = _pinnedMessage!.data() as Map<String, dynamic>;
      final messageId = _pinnedMessage!.id;

      // Navigate to and highlight the pinned message
      _highlightMessage(messageId);

      // Show a snackbar to indicate it's the pinned message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Want to unpin this message?'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Unpin',
            textColor: Colors.white,
            onPressed: _handleUnpinAction,
          ),
        ),
      );
    }
  }

  int _calculateTotalItemCount(
    Map<String, List<QueryDocumentSnapshot>> groupedMessages,
  ) {
    int count = 0;
    groupedMessages.forEach((date, messages) {
      count += 1 + messages.length;
    });
    return count;
  }

  Widget _buildMessageItem(
    int index,
    Map<String, List<QueryDocumentSnapshot>> groupedMessages,
  ) {
    int currentIndex = 0;

    final sortedDates =
        groupedMessages.keys.toList()..sort((a, b) {
          final dateA = _parseDateHeader(a);
          final dateB = _parseDateHeader(b);
          return dateA.compareTo(dateB);
        });

    for (final date in sortedDates) {
      final messages = groupedMessages[date]!;

      if (index == currentIndex) {
        return _buildDateHeader(date);
      }
      currentIndex++;

      for (int i = 0; i < messages.length; i++) {
        if (index == currentIndex) {
          final messageDoc = messages[i];
          final messageData = messageDoc.data() as Map<String, dynamic>;

          final text = messageData['text'] ?? '';
          final senderId = messageData['senderId'] ?? '';
          final timestamp = messageData['timestamp'] as Timestamp?;
          final isRead = messageData['isRead'] ?? false;
          final replyData = messageData['replyTo'] as Map<String, dynamic>?;
          final messageType = messageData['messageType'] ?? 'text';
          final imageUrl = messageData['imageUrl'];
          final audioUrl = messageData['audioUrl'];
          final audioDuration =
              messageData['duration'] != null
                  ? Duration(milliseconds: messageData['duration'])
                  : null;
          final isPinned = messageData['isPinned'] ?? false;

          final isMe = senderId == _auth.currentUser!.uid;
          final time =
              timestamp != null ? _formatMessageTime(timestamp.toDate()) : '';

          if (!_messageKeys.containsKey(messageDoc.id)) {
            _messageKeys[messageDoc.id] = GlobalKey();
          }

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 0) {
                _setReplyingToMessage({
                  'id': messageDoc.id,
                  'text': text,
                  'senderId': senderId,
                  'timestamp': timestamp,
                  'messageType': messageType,
                });
              }
            },
            child: MessageBubble(
              key: _messageKeys[messageDoc.id],
              messageId: messageDoc.id,
              text: text,
              time: time,
              isMe: isMe,
              isRead: isRead && isMe,
              replyData: replyData,
              isHighlighted: _highlightedMessageId == messageDoc.id || isPinned,
              messageType: messageType,
              imageUrl: imageUrl,
              audioUrl: audioUrl,
              audioDuration: audioDuration,
              isSelected: _selectedMessageIds.contains(messageDoc.id),
              showSelectionButtons: _isSelectionMode,
              onSelect: () {
                _toggleMessageSelection(messageDoc.id, isMe, messageData);
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(messageDoc.id, isMe, messageData);
                }
              },
              onReply: () {
                _setReplyingToMessage({
                  'id': messageDoc.id,
                  'text': text,
                  'senderId': senderId,
                  'timestamp': timestamp,
                  'messageType': messageType,
                });
              },
              onReplyTap:
                  replyData != null
                      ? () {
                        final originalMessageId = replyData['replyToMessageId'];
                        if (originalMessageId != null) {
                          _highlightMessage(originalMessageId);
                        }
                      }
                      : null,
              isPlaying: false,
              isForwarded: messageData['isForwarded'] ?? false,
            ),
          );
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  DateTime _parseDateHeader(String dateHeader) {
    final now = DateTime.now();

    if (dateHeader == 'Today') {
      return DateTime(now.year, now.month, now.day);
    } else if (dateHeader == 'Yesterday') {
      return DateTime(now.year, now.month, now.day - 1);
    } else {
      try {
        final parts = dateHeader.split(' ');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = _monthToNumber(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (e) {
        print('Error parsing date header: $e');
      }
      return now;
    }
  }

  int _monthToNumber(String month) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months.indexOf(month) + 1;
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_wallpaper.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_currentChatId == null) {
      return Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_wallpaper.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: _buildEncryptionNotice(),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}');
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/chat_wallpaper.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 50),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading messages',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/chat_wallpaper.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: _buildEncryptionNotice(),
          );
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/chat_wallpaper.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: _buildEncryptionNotice(),
          );
        }

        return _buildMessageList(snapshot.data);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _hideEmojiPicker();
        if (_editingMessageId != null) {
          _cancelEditing();
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 19, 18, 18),
        appBar:
            _isSelectionMode
                ? SelectedMessageAppBar(
                  selectedCount: _selectedMessageIds.length,
                  hasSenderMessages: _hasSenderMessagesSelected,
                  hasReceiverMessages: _hasReceiverMessagesSelected,
                  onClose: _clearSelection,
                  onReply: _handleReplyAction,
                  onEdit: _handleEditAction,
                  onCopy: _handleCopyAction,
                  onPin: _handlePinAction,
                  onForward: _handleForwardAction,
                  onDelete: _handleDeleteAction,
                )
                : MessageScreenAppBar(
                  name: widget.name,
                  avatarUrl: widget.avatarUrl,
                  isOnline: widget.isOnline,
                  onBackPressed: () => Navigator.pop(context),
                  onVideoCallPressed: () {
                    // TODO: Implement video call functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Video call functionality coming soon!'),
                      ),
                    );
                  },
                  onVoiceCallPressed: _initiateVoiceCall,
                ),
        body: Column(
          children: [
            // Pinned message stream listener
            StreamBuilder<DocumentSnapshot?>(
              stream: _pinnedMessageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Pinned message stream error: ${snapshot.error}');
                  return const SizedBox.shrink();
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                final pinnedMessageDoc = snapshot.data;

                // Update the pinned message state
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pinnedMessage != pinnedMessageDoc) {
                    setState(() {
                      _pinnedMessage = pinnedMessageDoc;
                    });
                  }
                });

                return const SizedBox.shrink();
              },
            ),

            Expanded(child: _buildBody()),

            // Show "Editing message" indicator when editing
            if (_editingMessageId != null && _editingMessageData != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing message',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16),
                      onPressed: _cancelEditing,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Reply preview widget
            if (_replyingToMessage != null)
              ReplyPreview(
                replyingToMessage: _replyingToMessage!,
                currentUserId: _auth.currentUser!.uid,
                onCancel: _cancelReply,
                onTapOriginal: () {
                  _highlightMessage(_replyingToMessage!['id']);
                },
                otherUserName: widget.name,
              ),

            // Voice recorder widget
            if (_showVoiceRecorder)
              VoiceRecorderWidget(
                onSendVoiceMessage: _sendVoiceMessage,
                onCancel: () {
                  setState(() {
                    _showVoiceRecorder = false;
                  });
                },
              )
            else
              // Message input field should always show
              MessageInputField(
                controller: _controller,
                onSend: _sendMessage,
                isReplying: _replyingToMessage != null,
                onAttachmentPressed: _showMediaPicker,
                onEmojiPressed: _toggleEmojiPicker,
                onVoiceNotePressed: _toggleVoiceRecorder,
                showEmojiPicker: _showEmojiPicker,
                showVoiceRecorder: _showVoiceRecorder,
                // Editing properties
                isEditing: _editingMessageId != null,
                onSaveEdit: _saveEditedMessage,
                onCancelEdit: _cancelEditing,
              ),

            // Emoji picker
            if (_showEmojiPicker)
              EmojiPickerWidget(
                controller: _controller,
                onBackspacePressed: () {
                  if (_controller.text.isNotEmpty) {
                    _controller.text = _controller.text.substring(
                      0,
                      _controller.text.length - 1,
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
