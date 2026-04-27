import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:wrytte/models/contact_model.dart';
import 'package:wrytte/services/auth/auth_service.dart';
import 'user_search_service.dart';

class ContactService {
  final UserSearchService _userSearchService = UserSearchService();

  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '+256${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('256')) {
      cleaned = '+$cleaned';
    }

    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }

    return cleaned;
  }

  Future<List<Contact>> getDeviceContacts() async {
    final hasPermission = await requestContactsPermission();

    if (!hasPermission) {
      throw Exception("Contacts permission denied");
    }

    final deviceContacts = await fc.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );

    final List<Contact> contacts = [];

    for (var c in deviceContacts) {
      final phones = <String>[];

      for (var p in c.phones) {
        final normalized = _normalizePhone(p.number);

        if (normalized.length >= 10) {
          phones.add(normalized);
        }
      }

      if (phones.isNotEmpty) {
        contacts.add(
          Contact(displayName: c.displayName, phones: phones, avatarUrl: null),
        );
      }
    }

    debugPrint("Loaded ${contacts.length} device contacts");

    return contacts;
  }

  Future<List<Contact>> getWrytteContactsOptimized() async {
    final deviceContacts = await getDeviceContacts();

    final allPhones =
        deviceContacts
            .expand((c) => c.phones)
            .where((p) => p.length >= 10)
            .toSet()
            .toList();

    if (allPhones.isEmpty) return [];

    final token = await AuthService.instance.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("User not authenticated");
    }

    final Map<String, String> phoneUserMap = {};

    try {
      const batchSize = 200;

      for (int i = 0; i < allPhones.length; i += batchSize) {
        final batch = allPhones.skip(i).take(batchSize).toList();

        debugPrint("Sending ${batch.length} phones to API");

        final phonesString = batch.join('|');

        final result = await _userSearchService.searchUsersByPhones(
          phoneNumbersC: phonesString,
          token: token,
        );

        phoneUserMap.addAll(result);
      }
    } catch (e) {
      debugPrint("User search failed: $e");
    }

    final List<Contact> wrytteContacts = [];

    for (final deviceContact in deviceContacts) {
      for (final phone in deviceContact.phones) {
        final normalizedPhone = _normalizePhone(phone);

        final userId = phoneUserMap[normalizedPhone];

        if (userId != null) {
          wrytteContacts.add(
            Contact(
              displayName: deviceContact.displayName,
              phones: deviceContact.phones,
              avatarUrl: deviceContact.avatarUrl,
              isOnWrytte: true,
              wrytteUserId: userId,
            ),
          );
          break;
        }
      }
    }

    debugPrint("Found ${wrytteContacts.length} Wrytte contacts");

    return wrytteContacts;
  }

  Future<List<Contact>> getNonWrytteContacts() async {
    final deviceContacts = await getDeviceContacts();
    final wrytteContacts = await getWrytteContactsOptimized();

    final wryttePhones = wrytteContacts.expand((c) => c.phones).toSet();

    final nonWrytte =
        deviceContacts
            .where((c) => !c.phones.any((p) => wryttePhones.contains(p)))
            .toList();

    debugPrint("Found ${nonWrytte.length} non-Wrytte contacts");

    return nonWrytte;
  }
}
