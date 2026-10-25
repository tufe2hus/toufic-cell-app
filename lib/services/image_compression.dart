import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes [bytes], downsizes it so its longest side is at most
/// [maxDimension], re-encodes as JPEG, and returns the result
/// base64-encoded — small enough to store inline in a Firestore document
/// instead of paying for Firebase Storage.
///
/// Runs on a background isolate via `compute()` since decoding and
/// resizing a full-resolution photo can take real time.
String compressImageToBase64(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unrecognized image format.');
  }

  const maxDimension = 640;
  final resized = decoded.width > maxDimension || decoded.height > maxDimension
      ? (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension))
      : decoded;

  var quality = 78;
  var encoded = img.encodeJpg(resized, quality: quality);
  // Step quality down until the payload comfortably fits inside
  // Firestore's per-document size limit.
  while (encoded.length > 500 * 1024 && quality > 30) {
    quality -= 12;
    encoded = img.encodeJpg(resized, quality: quality);
  }

  return base64Encode(encoded);
}
