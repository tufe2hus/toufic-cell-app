import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'picked_contact.dart';

/// `flutter_contacts` only supports Android/iOS — this is false on desktop
/// native builds, so the UI can hide the "Contacts" button there instead of
/// showing a button that would error when pressed. (Web has its own
/// implementation in `contacts_picker_web.dart`.)
bool get supportsContactPicker =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Requests contacts permission and opens the native contact picker,
/// returning the selected contact's name and first phone number, or `null`
/// if the user cancelled, denied permission, or picked a contact with no
/// phone number.
Future<PickedContact?> pickPhoneContact() async {
  if (!supportsContactPicker) {
    return null;
  }
  try {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      return null;
    }
    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) {
      return null;
    }
    final full = await FlutterContacts.getContact(picked.id, withProperties: true) ?? picked;
    if (full.phones.isEmpty) {
      return PickedContact(name: full.displayName, phone: '');
    }
    return PickedContact(name: full.displayName, phone: full.phones.first.number);
  } catch (error) {
    debugPrint('Contact pick failed: $error');
    return null;
  }
}
