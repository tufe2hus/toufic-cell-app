import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// On mobile web, the generic file picker's chooser doesn't always surface a
/// direct "take photo" shortcut, so we open the device camera explicitly via
/// an `<input capture>` element instead.
bool get supportsDirectCameraCapture => true;

Future<Uint8List?> captureImageFromCamera() =>
    _pickImage(capture: 'environment');

/// Opens the photo gallery/library via a raw `<input type=file>` element
/// instead of the `file_picker` package. `file_picker`'s web implementation
/// is known to intermittently fail to open the native picker on iOS
/// Safari/Chrome; a directly-clicked, unwrapped `<input>` element (this same
/// technique [captureImageFromCamera] above already uses) opens reliably
/// there. Omitting the `capture` attribute (unlike the camera capture above)
/// is what makes iOS show the full "Photo Library / Take Photo / Choose
/// File" picker instead of jumping straight to the camera.
Future<Uint8List?> pickImageFromGallery() => _pickImage();

Future<Uint8List?> _pickImage({String? capture}) async {
  final completer = Completer<Uint8List?>();
  var completed = false;

  void finish(Uint8List? bytes) {
    if (completed) {
      return;
    }
    completed = true;
    completer.complete(bytes);
  }

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  if (capture != null) {
    input.setAttribute('capture', capture);
  }

  void handleChange(web.Event event) {
    final files = input.files;
    final file = (files == null || files.length == 0) ? null : files.item(0);
    input.remove();
    if (file == null) {
      finish(null);
      return;
    }

    final reader = web.FileReader();
    reader.onLoadEnd.listen((event) {
      final result = reader.result;
      if (result != null && result.isA<JSArrayBuffer>()) {
        finish((result as JSArrayBuffer).toDart.asUint8List());
      } else {
        finish(null);
      }
    });
    reader.readAsArrayBuffer(file);
  }

  void handleCancelled(web.Event event) {
    web.window.removeEventListener('focus', handleCancelled.toJS);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!completed) {
        input.remove();
        finish(null);
      }
    });
  }

  input.addEventListener('change', handleChange.toJS);
  web.window.addEventListener('focus', handleCancelled.toJS);

  web.document.body!.append(input);
  input.click();

  return completer.future;
}
