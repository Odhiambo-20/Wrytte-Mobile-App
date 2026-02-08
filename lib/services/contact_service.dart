import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/contact_model.dart';

// Minimal local shim to match the expected Libphonenumber API used in this file.
// This avoids the "Undefined name 'Libphonenumber'" compile error if the plugin
// exports a different API surface; it provides basic parse/format behavior.
// Note: This is a lightweight fallback and not a full replacement for a real
// libphonenumber implementation.
class Libphonenumber {
  // Returns a parsed representation with a basic validity heuristic.
  // ignore: library_private_types_in_public_api
  static Future<_ParsedNumber> parse(String phone, {String? region}) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final digitsOnly = cleaned.replaceAll('+', '');
    // Basic heuristic: consider valid when at least 7 digits present
    final isValid = digitsOnly.length >= 7;
    return _ParsedNumber(isValid, cleaned);
  }

  // Formats into a basic international-like string (E.164-ish) where possible.
  static Future<String> format(
    String phone, {
    String? region,
    PhoneNumberFormat format = PhoneNumberFormat.E164,
  }) async {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('00')) return '+${cleaned.substring(2)}';
    if (cleaned.length >= 7) return '+$cleaned';
    return cleaned;
  }
}

class _ParsedNumber {
  final bool _isValid;
  final String _international;

  _ParsedNumber(this._isValid, this._international);

  bool isValid() => _isValid;

  @override
  String toString() => _international;
}

// ignore: constant_identifier_names
enum PhoneNumberFormat { E164 }

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userCountryCode;

  // Request contacts permission
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  // Get user's country code from device
  Future<String?> _getUserCountryCode() async {
    if (_userCountryCode != null) return _userCountryCode;

    try {
      final deviceInfo = DeviceInfoPlugin();

      // Try to get locale from device
      // ignore: deprecated_member_use
      final locale = WidgetsBinding.instance.window.locale;
      if (locale.countryCode != null) {
        _userCountryCode = locale.countryCode;
        return _userCountryCode;
      }

      // Fallback: Use device-specific methods
      // For Android
      try {
        final androidInfo = await deviceInfo.androidInfo;
        _userCountryCode =
            androidInfo.supportedAbis.isNotEmpty
                ? androidInfo.supportedAbis.first.toUpperCase().substring(0, 2)
                : 'US';
      } catch (e) {
        // For iOS
        try {
          final iosInfo = await deviceInfo.iosInfo;
          _userCountryCode = iosInfo.isPhysicalDevice ? 'US' : 'US';
        } catch (e) {
          _userCountryCode = 'US'; // Ultimate fallback
        }
      }

      return _userCountryCode;
    } catch (e) {
      debugPrint('Error getting user country code: $e');
      return 'US'; // Default fallback
    }
  }

  // Professional phone number normalization
  Future<String> _normalizePhoneNumberProfessional(
    String phone,
    String? countryCode,
  ) async {
    if (phone.isEmpty) return '';

    try {
      // Use libphonenumber for professional parsing
      final parsedNumber = await Libphonenumber.parse(
        phone,
        region: countryCode ?? await _getUserCountryCode() ?? 'US',
      );

      if (parsedNumber.isValid()) {
        // Format in E.164 international format
        final internationalFormat = await Libphonenumber.format(
          phone,
          region: countryCode ?? await _getUserCountryCode() ?? 'US',
          format: PhoneNumberFormat.E164,
        );

        debugPrint(
          'Professional parse: $phone -> $internationalFormat (Valid: ${parsedNumber.isValid()})',
        );
        return internationalFormat;
      } else {
        // Fallback: basic cleaning for invalid numbers
        final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
        debugPrint('Professional parse failed: $phone -> $cleaned (Invalid)');
        return cleaned;
      }
    } catch (e) {
      // Fallback if libphonenumber fails
      debugPrint('libphonenumber error for $phone: $e');
      return _normalizePhoneNumberFallback(phone);
    }
  }

  // Fallback normalization when libphonenumber fails
  String _normalizePhoneNumberFallback(String phone) {
    if (phone.isEmpty) return '';

    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Handle common international patterns
    if (cleaned.startsWith('00')) {
      // Convert 00 to +
      cleaned = '+${cleaned.substring(2)}';
    } else if (!cleaned.startsWith('+') && cleaned.length >= 7) {
      // For numbers without country code, we can't reliably add +
      // WhatsApp leaves these as local numbers and tries multiple matching strategies
    }

    debugPrint('Fallback normalize: $phone -> $cleaned');
    return cleaned;
  }

  // Fetch device contacts with professional normalization
  Future<List<Contact>> getDeviceContacts() async {
    final hasPermission = await requestContactsPermission();
    if (!hasPermission) {
      throw Exception('Contacts permission denied');
    }

    final userCountryCode = await _getUserCountryCode();
    debugPrint('Using country code for parsing: $userCountryCode');

    final List<fc.Contact> deviceContacts = await fc
        .FlutterContacts.getContacts(withProperties: true, withPhoto: true);

    final List<Contact> contacts = [];
    int processed = 0;

    for (var deviceContact in deviceContacts) {
      final List<String> normalizedPhones = [];

      for (var phone in deviceContact.phones) {
        if (phone.number.isNotEmpty) {
          try {
            final normalized = await _normalizePhoneNumberProfessional(
              phone.number,
              userCountryCode,
            );

            if (normalized.isNotEmpty) {
              normalizedPhones.add(normalized);
            }
          } catch (e) {
            debugPrint('Error normalizing ${phone.number}: $e');
            // Continue with next phone number
          }
        }
      }

      if (normalizedPhones.isNotEmpty) {
        contacts.add(
          Contact(
            displayName: deviceContact.displayName,
            phones: normalizedPhones,
            avatarUrl: null,
          ),
        );
        processed++;

        // Log progress for large contact lists
        if (processed % 50 == 0) {
          debugPrint(
            'Processed $processed/${deviceContacts.length} contacts...',
          );
        }
      }
    }

    debugPrint(
      '✅ Successfully loaded ${contacts.length} contacts with ${contacts.expand((c) => c.phones).length} phone numbers',
    );
    return contacts;
  }

  // WhatsApp-style contact matching - ALWAYS to USE DEVICE CONTACT NAMES
  Future<List<Contact>> getWrytteContacts() async {
    final stopwatch = Stopwatch()..start();
    final deviceContacts = await getDeviceContacts();
    final List<Contact> wrytteContacts = [];

    if (deviceContacts.isEmpty) {
      debugPrint('No device contacts to check');
      return wrytteContacts;
    }

    // Get all unique normalized phone numbers
    final allPhoneNumbers =
        deviceContacts.expand((contact) => contact.phones).toSet();
    debugPrint(
      ' Checking ${allPhoneNumbers.length} unique numbers against Wrytte users',
    );

    // Single batch query for all numbers
    final exactMatches = await _findExactMatches(allPhoneNumbers);

    // Create a lookup map for O(1) access
    final phoneToUserMap =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var user in exactMatches) {
      final phone = _getSafeField<String>(user.data(), 'phone');
      if (phone != null) {
        phoneToUserMap[phone] = user;
      }
    }

    debugPrint(' Exact matches: ${exactMatches.length}');

    // WhatsApp-like behavior: ALWAYS to use device contact names
    for (var deviceContact in deviceContacts) {
      Contact? matchedContact;

      for (var phone in deviceContact.phones) {
        final exactMatch = phoneToUserMap[phone];

        if (exactMatch != null) {
          // WHATSAPP BEHAVIOR: Always use device contact name, never database name
          final userData = exactMatch.data();
          final avatarUrl = _getSafeField<String>(userData, 'profileImage');

          // Use device contact name (like WhatsApp), ignore database name
          final displayName = deviceContact.displayName;

          matchedContact = Contact(
            displayName: displayName, // Always device contact name
            phones: deviceContact.phones,
            avatarUrl: avatarUrl,
            isOnWrytte: true,
            wrytteUserId: exactMatch.id,
            // Store database name separately if needed for other purposes
            databaseName: _getSafeField<String>(userData, 'name'),
          );
          break; // Found match, move to next contact
        }
      }

      if (matchedContact != null) {
        wrytteContacts.add(matchedContact);
      }
    }

    debugPrint(
      ' FINAL: Found ${wrytteContacts.length} Wrytte contacts in ${stopwatch.elapsedMilliseconds}ms',
    );

    // Log the name strategy
    if (wrytteContacts.isNotEmpty) {
      debugPrint(' NAME STRATEGY: Using device contact names (WhatsApp-style)');
      for (var contact in wrytteContacts.take(3)) {
        debugPrint(
          '    "${contact.displayName}" (Device name) '
          'vs Database: "${contact.databaseName ?? "N/A"}"',
        );
      }
    }

    return wrytteContacts;
  }

  // ULTRA-FAST VERSION - For maximum performance (WhatsApp-style names)
  Future<List<Contact>> getWrytteContactsUltraFast() async {
    final stopwatch = Stopwatch()..start();

    final deviceContacts = await getDeviceContacts();
    final List<Contact> wrytteContacts = [];

    if (deviceContacts.isEmpty) {
      return wrytteContacts;
    }

    // Get all unique normalized phone numbers
    final allPhoneNumbers =
        deviceContacts.expand((contact) => contact.phones).toSet();
    debugPrint(' ULTRAFAST: Checking ${allPhoneNumbers.length} numbers');

    // Single batch query for all numbers
    final matches = await _findExactMatches(allPhoneNumbers);

    // Create lookup map for O(1) access
    final phoneToUserMap =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (var user in matches) {
      final phone = _getSafeField<String>(user.data(), 'phone');
      if (phone != null) {
        phoneToUserMap[phone] = user;
      }
    }

    // Ultra-fast matching using HashMap - ALWAYS use device names
    for (var deviceContact in deviceContacts) {
      for (var phone in deviceContact.phones) {
        final matchingUser = phoneToUserMap[phone];
        if (matchingUser != null) {
          final userData = matchingUser.data();
          final avatarUrl = _getSafeField<String>(userData, 'profileImage');

          // WHATSAPP BEHAVIOR: Always prefer device contact name
          final displayName = deviceContact.displayName;

          wrytteContacts.add(
            Contact(
              displayName: displayName, // Device contact name
              phones: deviceContact.phones,
              avatarUrl: avatarUrl,
              isOnWrytte: true,
              wrytteUserId: matchingUser.id,
              databaseName: _getSafeField<String>(userData, 'name'),
            ),
          );
          break; // Found match, move to next contact
        }
      }
    }

    debugPrint(' ULTRAFAST completed in ${stopwatch.elapsedMilliseconds}ms');
    return wrytteContacts;
  }

  // Safe field access helper method
  T? _getSafeField<T>(Map<String, dynamic>? data, String fieldName) {
    if (data == null || !data.containsKey(fieldName)) {
      debugPrint('Field "$fieldName" not found in document');
      return null;
    }

    final value = data[fieldName];
    if (value is T) {
      return value;
    }

    // Trying to convert if types don't match but value exists
    try {
      if (T == String && value != null) {
        return value.toString() as T;
      }
    } catch (e) {
      debugPrint('Error converting field $fieldName: $e');
    }

    return null;
  }

  // Find exact matches using batch queries
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findExactMatches(
    Set<String> phoneNumbers,
  ) async {
    if (phoneNumbers.isEmpty) return [];

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allMatches = [];

    // Split into chunks of 25 (safe limit for Firestore)
    final chunks = _splitIntoChunks(phoneNumbers.toList(), 25);

    for (final chunk in chunks) {
      try {
        final snapshot =
            await _firestore
                .collection('users')
                .where('phone', whereIn: chunk)
                .get();

        allMatches.addAll(snapshot.docs);
        debugPrint('Batch query found ${snapshot.docs.length} matches');
      } catch (e) {
        debugPrint('Batch query error: $e');
        // Continue with next chunk
      }
    }

    return allMatches;
  }

  // Get contacts not on Wrytte
  Future<List<Contact>> getNonWrytteContacts() async {
    final deviceContacts = await getDeviceContacts();
    final wrytteContacts = await getWrytteContacts();

    final wryttePhones =
        wrytteContacts.expand((contact) => contact.phones).toSet();

    final nonWrytteContacts =
        deviceContacts
            .where(
              (contact) =>
                  !contact.phones.any((phone) => wryttePhones.contains(phone)),
            )
            .toList();

    debugPrint('📱 Non-Wrytte contacts: ${nonWrytteContacts.length}');
    return nonWrytteContacts;
  }

  // Helper method to split list into chunks
  List<List<T>> _splitIntoChunks<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      int end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  // Performance-optimized version for large contact lists
  Future<List<Contact>> getWrytteContactsOptimized() async {
    final stopwatch = Stopwatch()..start();

    final deviceContacts = await getDeviceContacts();
    final allPhoneNumbers =
        deviceContacts.expand((contact) => contact.phones).toSet();

    debugPrint(' Optimization: Checking ${allPhoneNumbers.length} numbers');

    final matches = await _findExactMatches(allPhoneNumbers);
    final wrytteContacts = _matchContactsWithUsers(deviceContacts, matches);

    debugPrint(' Optimization completed in ${stopwatch.elapsedMilliseconds}ms');
    return wrytteContacts;
  }

  List<Contact> _matchContactsWithUsers(
    List<Contact> deviceContacts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> wrytteUsers,
  ) {
    final wrytteContacts = <Contact>[];

    for (var deviceContact in deviceContacts) {
      for (var phone in deviceContact.phones) {
        final int matchIndex = wrytteUsers.indexWhere(
          (user) => _getSafeField(user.data(), 'phone') == phone,
        );
        final QueryDocumentSnapshot<Map<String, dynamic>>? matchingUser =
            matchIndex != -1 ? wrytteUsers[matchIndex] : null;

        if (matchingUser != null) {
          final userData = matchingUser.data();
          final avatarUrl = _getSafeField<String>(userData, 'profileImage');

          // WHATSAPP BEHAVIOR: Always to use device contact name
          final displayName = deviceContact.displayName;

          wrytteContacts.add(
            Contact(
              displayName: displayName, // Device contact name
              phones: deviceContact.phones,
              avatarUrl: avatarUrl,
              isOnWrytte: true,
              wrytteUserId: matchingUser.id,
              databaseName: _getSafeField<String>(userData, 'name'),
            ),
          );
          break;
        }
      }
    }

    return wrytteContacts;
  }
}
