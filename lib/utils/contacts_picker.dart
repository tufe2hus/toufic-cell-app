import 'contacts_picker_io.dart' if (dart.library.js_interop) 'contacts_picker_web.dart' as impl;
import 'picked_contact.dart';

export 'picked_contact.dart' show PickedContact;

/// Whether the "pick from contacts" button should be shown on this
/// platform/browser — Android/iOS natively, or web when the browser exposes
/// the Contact Picker API (Chrome/Edge on Android only; see
/// `contacts_picker_web.dart`).
bool get supportsContactPicker => impl.supportsContactPicker;

/// Opens the platform's contact picker and returns the selected contact's
/// name and first phone number, or `null` if the user cancelled, denied
/// permission, or the platform doesn't support it.
Future<PickedContact?> pickPhoneContact() => impl.pickPhoneContact();
