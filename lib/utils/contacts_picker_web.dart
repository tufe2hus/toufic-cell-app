import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'picked_contact.dart';

/// The browser Contact Picker API (`navigator.contacts.select`) — currently
/// only implemented by Chrome/Edge on Android, invoked from a real user
/// gesture over HTTPS. No browser exposes contacts to a website on desktop
/// or on iOS at all (a deliberate privacy restriction, not something this
/// app can work around), so [supportsContactPicker] is false there and the
/// UI hides the "Contacts" button instead of showing one that would do
/// nothing.
bool get supportsContactPicker {
  try {
    return (web.window.navigator as JSObject).has('contacts');
  } catch (_) {
    return false;
  }
}

Future<PickedContact?> pickPhoneContact() async {
  if (!supportsContactPicker) {
    return null;
  }
  try {
    final navigator = web.window.navigator as JSObject;
    final contactsManager = navigator.getProperty<JSObject>('contacts'.toJS);
    final properties = <JSAny>['name'.toJS, 'tel'.toJS].toJS;
    final options = JSObject()..setProperty('multiple'.toJS, false.toJS);
    final resultPromise = contactsManager.callMethod<JSPromise<JSArray>>(
      'select'.toJS,
      properties,
      options,
    );
    final contacts = await resultPromise.toDart;
    if (contacts.length == 0) {
      return null;
    }
    final contact = contacts.toDart.first as JSObject;
    final name = _firstString(contact, 'name');
    final phone = _firstString(contact, 'tel');
    if (name.isEmpty && phone.isEmpty) {
      return null;
    }
    return PickedContact(name: name, phone: phone);
  } catch (error) {
    debugPrint('Web contact pick failed: $error');
    return null;
  }
}

String _firstString(JSObject contact, String key) {
  final values = contact.getProperty<JSArray?>(key.toJS);
  if (values == null || values.length == 0) {
    return '';
  }
  final first = values.toDart.first;
  return first.isA<JSString>() ? (first as JSString).toDart : '';
}
