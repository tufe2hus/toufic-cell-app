/// A contact picked from the device/browser, shared by the native
/// (`contacts_picker_io.dart`) and web (`contacts_picker_web.dart`)
/// implementations behind `contacts_picker.dart`.
class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}
