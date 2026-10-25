import 'dart:typed_data';

/// Native platforms already get a real camera option from the OS file/photo
/// picker that [FilePicker] opens, so no extra direct-capture path is needed.
bool get supportsDirectCameraCapture => false;

Future<Uint8List?> captureImageFromCamera() async => null;

/// Native platforms use `file_picker`'s own OS-level picker (see
/// `product_management_screen.dart`), which already opens reliably there —
/// this direct-input path is only needed to work around a web-specific
/// `file_picker` quirk on iOS Safari/Chrome.
Future<Uint8List?> pickImageFromGallery() async => null;
