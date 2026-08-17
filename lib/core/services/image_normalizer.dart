import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ConexoImageNormalizer {
  const ConexoImageNormalizer._();

  static const int _jpegQuality = 92;
  static const int _maxDimension = 2048;

  static Future<NormalizedImage> normalize(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('Empty image bytes');
    }

    Uint8List workingBytes = bytes;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      int width = image.width;
      int height = image.height;

      if (width > _maxDimension || height > _maxDimension) {
        if (width > height) {
          if (width > _maxDimension) {
            height = (height * _maxDimension / width).round();
            width = _maxDimension;
          }
        } else {
          if (height > _maxDimension) {
            width = (width * _maxDimension / height).round();
            height = _maxDimension;
          }
        }

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
        final picture = recorder.endRecording();
        final resizedImage = await picture.toImage(width, height);
        final byteData =
            await resizedImage.toByteData(format: ui.ImageByteFormat.png);
        workingBytes = byteData!.buffer.asUint8List();
      }
    } catch (e) {
      // If dart:ui decoding fails (e.g. unsupported format), fall back to the
      // original bytes and let flutter_image_compress handle conversion.
    }

    final result = await FlutterImageCompress.compressWithList(
      workingBytes,
      quality: _jpegQuality,
      autoCorrectionAngle: true,
      keepExif: false,
    );

    if (result.isEmpty) {
      throw const FormatException('Failed to normalize image');
    }

    return NormalizedImage(
      bytes: result,
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
  }
}

class NormalizedImage {
  const NormalizedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}
