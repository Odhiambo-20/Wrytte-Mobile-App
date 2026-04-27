import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallListenerService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _incomingCallSubscription;

  void startListening(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
  }

  void stopListening() {
    _incomingCallSubscription?.cancel();
  }
}
