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

    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }

    if (!cleaned.startsWith('+') && cleaned.length >= 9) {
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

        if (normalized.isNotEmpty) {
          phones.add(normalized);
        }
      }

      if (phones.isNotEmpty) {
        contacts.add(
          Contact(displayName: c.displayName, phones: phones, avatarUrl: null),
        );
      }
    }

    debugPrint("Loaded ${contacts.length} contacts");

    return contacts;
  }

  Future<List<Contact>> getWrytteContactsOptimized() async {
    final deviceContacts = await getDeviceContacts();

    final allPhones = deviceContacts.expand((c) => c.phones).toSet().toList();

    if (allPhones.isEmpty) return [];

    final token = await AuthService.instance.getToken();

    final users = await _userSearchService.searchUsersByPhones(
      allPhones,
      token!,
    );

    final Map<String, Map<String, dynamic>> phoneUserMap = {};

    for (final user in users) {
      final phone = user["phoneNumber"];

      if (phone != null) {
        phoneUserMap[phone] = user;
      }
    }

    final List<Contact> wrytteContacts = [];

    for (final deviceContact in deviceContacts) {
      for (final phone in deviceContact.phones) {
        final user = phoneUserMap[phone];

        if (user != null) {
          wrytteContacts.add(
            Contact(
              displayName: deviceContact.displayName,
              phones: deviceContact.phones,
              avatarUrl: null,
              isOnWrytte: true,
              wrytteUserId: user["userid"].toString(),
            ),
          );
          break;
        }
      }
    }

    return wrytteContacts;
  }

  Future<List<Contact>> getNonWrytteContacts() async {
    final deviceContacts = await getDeviceContacts();
    final wrytteContacts = await getWrytteContactsOptimized();

    final wryttePhones = wrytteContacts.expand((c) => c.phones).toSet();

    return deviceContacts
        .where((c) => !c.phones.any((p) => wryttePhones.contains(p)))
        .toList();
  }
}
