import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/services/call_service.dart';
import 'package:wrytte/ui/screens/calls/incoming_call_screen.dart';

class CallListenerService {
  final CallService _callService = CallService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _incomingCallSubscription;

  void startListening(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _incomingCallSubscription = _callService
        .getIncomingCalls(currentUser.uid)
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            _showIncomingCallDialog(context, data);
          }
        });
  }

  void _showIncomingCallDialog(
    BuildContext context,
    Map<String, dynamic> callData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => IncomingCallScreen(
              callId: callData['callId'],
              callerId: callData['callerId'],
              callerName: callData['callerName'],
              callerAvatar: callData['callerAvatar'] ?? '',
              isVideoCall: callData['isVideoCall'] ?? false,
              callerPhoneNumber: '',
            ),
      ),
    );
  }

  void stopListening() {
    _incomingCallSubscription?.cancel();
  }
}
