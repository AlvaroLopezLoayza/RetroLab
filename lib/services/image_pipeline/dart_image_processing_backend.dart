library;

import 'dart:typed_data';

import 'image_processing_backend.dart';
import 'image_processing_request.dart';

typedef DartImageProcessor =
    Future<Uint8List> Function({
      required Uint8List originalBytes,
      required ImageProcessingRequest request,
      Uint8List? scratchBytes,
      Uint8List? leakBytes,
      Uint8List? dustBytes,
    });

class DartImageProcessingBackend implements ImageProcessingBackend {
  final DartImageProcessor _processor;

  const DartImageProcessingBackend(this._processor);

  @override
  Future<Uint8List> process({
    required Uint8List originalBytes,
    required ImageProcessingRequest request,
    Uint8List? scratchBytes,
    Uint8List? leakBytes,
    Uint8List? dustBytes,
  }) {
    return _processor(
      originalBytes: originalBytes,
      request: request,
      scratchBytes: scratchBytes,
      leakBytes: leakBytes,
      dustBytes: dustBytes,
    );
  }
}
