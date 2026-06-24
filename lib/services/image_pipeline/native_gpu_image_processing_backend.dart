library;

import 'package:flutter/services.dart';

import 'image_processing_backend.dart';
import 'image_processing_request.dart';

class NativeGpuImageProcessingBackend implements ImageProcessingBackend {
  static const _channel = MethodChannel('retrolab/native_image_processor');

  @override
  Future<Uint8List> process({
    required Uint8List originalBytes,
    required ImageProcessingRequest request,
    Uint8List? scratchBytes,
    Uint8List? leakBytes,
    Uint8List? dustBytes,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>('processImage', {
      'imageBytes': originalBytes,
      'request': request.toMap(),
      'scratchBytes': scratchBytes,
      'leakBytes': leakBytes,
      'dustBytes': dustBytes,
    });
    if (result == null) {
      throw StateError('Native processor returned null');
    }
    return result;
  }
}
