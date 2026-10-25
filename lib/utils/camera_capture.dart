import 'dart:typed_data';

import 'camera_capture_stub.dart'
    if (dart.library.js_interop) 'camera_capture_web.dart'
    as impl;

/// Whether this platform can open the device camera directly (bypassing the
/// generic file/gallery chooser). Currently true only on web.
bool get supportsDirectCameraCapture => impl.supportsDirectCameraCapture;

/// Opens the device camera and returns the captured photo's bytes, or `null`
/// if the user cancelled. Only meaningful when [supportsDirectCameraCapture]
/// is true.
Future<Uint8List?> captureImageFromCamera() => impl.captureImageFromCamera();

/// Whether [pickImageFromGallery] should be used instead of the generic
/// `file_picker` package. True only on web — `file_picker`'s web
/// implementation is unreliable on iOS Safari/Chrome (the picker
/// intermittently never opens), so web uses a hand-rolled `<input type=file>`
/// element instead, matching the technique [captureImageFromCamera] already
/// uses successfully for the camera button. Native platforms keep using
/// `file_picker`, which opens the OS's own picker correctly there.
bool get usesDirectGalleryPicker => impl.supportsDirectCameraCapture;

/// Opens the photo gallery/library directly (bypassing `file_picker`) and
/// returns the selected photo's bytes, or `null` if the user cancelled.
/// Only meaningful when [usesDirectGalleryPicker] is true.
Future<Uint8List?> pickImageFromGallery() => impl.pickImageFromGallery();
