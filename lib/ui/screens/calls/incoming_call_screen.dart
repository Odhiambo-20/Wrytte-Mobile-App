import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wrytte/services/call_service.dart';
import 'package:wrytte/ui/screens/calls/voice_call_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhoneNumber;
  final String callerAvatar;
  final bool isVideoCall;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoneNumber,
    required this.callerAvatar,
    required this.isVideoCall,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  Timer? _callTimer;
  int _callDuration = 0;
  bool _callAccepted = false;
  bool _callRejected = false;
  bool _callEnded = false;
  String _displayName = '';
  bool _isLoading = true;
  bool _hasContactName = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _playRingtone();
    _fetchCallerInfo();
  }

  Future<void> _fetchCallerInfo() async {
    try {
      // First check if we have a saved contact name
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final contactDoc =
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .collection('contacts')
                .doc(widget.callerId)
                .get();

        if (contactDoc.exists && contactDoc.data()?['savedName'] != null) {
          setState(() {
            _displayName = contactDoc.data()!['savedName'];
            _hasContactName = true;
          });
        } else {
          // If no saved name, use the name from call data or phone number
          setState(() {
            _displayName =
                widget.callerName.isNotEmpty
                    ? widget.callerName
                    : _formatPhoneNumber(widget.callerPhoneNumber);
            _hasContactName = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching caller info: $e');
      setState(() {
        _displayName =
            widget.callerName.isNotEmpty
                ? widget.callerName
                : _formatPhoneNumber(widget.callerPhoneNumber);
        _hasContactName = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Simple phone number formatting
    if (phoneNumber.length <= 10) return phoneNumber;
    return '${phoneNumber.substring(0, 4)} **** ${phoneNumber.substring(phoneNumber.length - 3)}';
  }

  void _initializeCall() {
    // Listen for call status updates
    _callService.getCallStream(widget.callId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'calling';

        if (status == 'ended' || status == 'rejected') {
          _onCallEnded();
        } else if (status == 'accepted') {
          // Call was accepted by the caller
        }
      } else {
        _onCallEnded();
      }
    });

    // Start call timer if call gets connected
    _startCallTimer();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callAccepted && !_callEnded) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _playRingtone() async {
    try {
      // Play ringtone - to add my ringtone file
      // await _ringtonePlayer.play(AssetSource('audio/ringtone.mp3'));

      // Loop the ringtone
      _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  void _stopRingtone() {
    _ringtonePlayer.stop();
  }

  void _onCallEnded() {
    if (_callEnded) return;

    _callEnded = true;
    _stopRingtone();
    _callTimer?.cancel();

    // Delay to show call ended state briefly
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _acceptCall() async {
    if (_callAccepted || _callRejected || _callEnded) return;

    try {
      await _callService.acceptCall(widget.callId);

      setState(() {
        _callAccepted = true;
      });

      _stopRingtone();

      // Navigate to voice call screen
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => VoiceCallScreen(
                receiverId: widget.callerId,
                receiverName: _displayName,
                receiverAvatar: widget.callerAvatar,
                callId: widget.callId,
                isIncomingCall: true,
              ),
        ),
      );
    } catch (e) {
      print('Error accepting call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept call'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCall() async {
    if (_callRejected || _callEnded) return;

    try {
      await _callService.rejectCall(widget.callId);

      setState(() {
        _callRejected = true;
      });

      _stopRingtone();
      _onCallEnded();
    } catch (e) {
      print('Error rejecting call: $e');
      // Still close the screen even if Firebase update fails
      _onCallEnded();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1D2C),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_wallpaper.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with call info
              _buildCallHeader(),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Call type indicator
                    _buildCallTypeIndicator(),
                    const SizedBox(height: 40),

                    // Caller info
                    _buildCallerInfo(),
                    const SizedBox(height: 20),

                    // Call status/duration
                    if (_callAccepted) _buildCallDuration(),
                  ],
                ),
              ),

              // Call controls
              if (!_callAccepted && !_callRejected && !_callEnded)
                _buildCallControls(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time/date
          Text(
            TimeOfDay.now().format(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Battery indicator
          const Row(
            children: [
              Icon(Icons.battery_std, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Icon(Icons.network_cell, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Icon(Icons.wifi, color: Colors.white, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.isVideoCall ? 'Incoming Video Call' : 'Incoming Voice Call',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    if (_isLoading) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return Column(
      children: [
        // Caller avatar
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.green, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 85,
                backgroundColor: Colors.transparent,
                backgroundImage:
                    widget.callerAvatar.isNotEmpty
                        ? NetworkImage(widget.callerAvatar)
                        : null,
                child:
                    widget.callerAvatar.isEmpty
                        ? Icon(Icons.person, size: 80, color: Colors.white)
                        : null,
              ),

              // Pulsating animation for ringing effect
              if (!_callAccepted && !_callRejected && !_callEnded)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Caller name
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // Phone number if no contact name
              if (!_hasContactName && widget.callerPhoneNumber.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.callerPhoneNumber,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Call status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _callAccepted ? 'Connected' : 'Calling...',
            style: TextStyle(
              color: _callAccepted ? Colors.greenAccent : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallDuration() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        _formatDuration(_callDuration),
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject button
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red.withOpacity(0.8),
            isLarge: true,
            onPressed: _rejectCall,
          ),

          // Accept button
          _buildControlButton(
            icon: widget.isVideoCall ? Icons.videocam : Icons.call,
            backgroundColor: Colors.green.withOpacity(0.8),
            isLarge: true,
            onPressed: _acceptCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 70 : 60,
      height: isLarge ? 70 : 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: isLarge ? 35 : 30),
        onPressed: onPressed,
      ),
    );
  }
}
