library;

import 'dart:typed_data';

import 'image_processing_request.dart';

abstract class ImageProcessingBackend {
  Future<Uint8List> process({
    required Uint8List originalBytes,
    required ImageProcessingRequest request,
    Uint8List? scratchBytes,
    Uint8List? leakBytes,
    Uint8List? dustBytes,
  });
}
