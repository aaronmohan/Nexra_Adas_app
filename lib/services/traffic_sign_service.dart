import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

class TrafficSignService {

  Interpreter? _interpreter;

  List<String> _labels = [];

  String? _lastLabel;

  int _stableCount = 0;

  final int inputSize = 32;

  // ================= INIT =================

  Future<void> init() async {

    _interpreter = await Interpreter.fromAsset(
      'assets/ml_models/traffic_signs.tflite',
    );

    final labelData =
        await rootBundle.loadString(
      'assets/labels/labels.txt',
    );

    _labels = labelData
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    print("Labels count: ${_labels.length}");
  }

  // ================= SIGN EXTRACTION =================

  img.Image? extractSign(img.Image image) {

    int minX = image.width;
    int minY = image.height;

    int maxX = 0;
    int maxY = 0;

    int redPixels = 0;

    for (int y = 0; y < image.height; y += 2) {

      for (int x = 0; x < image.width; x += 2) {

        final pixel = image.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Detect red traffic sign area
        if (r > 150 && g < 120 && b < 120) {

          redPixels++;

          if (x < minX) minX = x;
          if (y < minY) minY = y;

          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    print("Red pixels: $redPixels");

    // No sign detected
    if (redPixels < 300) {
      return null;
    }

    // Prevent invalid crop
    if ((maxX - minX) <= 0 || (maxY - minY) <= 0) {
      return null;
    }

    // Crop detected sign region
    return img.copyCrop(
      image,
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  // ================= CLASSIFICATION =================

  String? detect(img.Image image) {

    if (_interpreter == null) return null;

    // Resize to model input size
    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    // Prepare input tensor
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {

            final pixel = resized.getPixel(x, y);

            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    // Output tensor
    final output = List.generate(
      1,
      (_) => List.filled(43, 0.0),
    );

    _interpreter!.run(input, output);

    // Find highest confidence
    double maxScore = 0;

    int maxIndex = 0;

    for (int i = 0; i < 43; i++) {

      if (output[0][i] > maxScore) {

        maxScore = output[0][i];

        maxIndex = i;
      }
    }

    print("Confidence: $maxScore");

    // Ignore weak predictions
    if (maxScore < 0.90) {
      return null;
    }

    final detectedLabel =
    _labels[maxIndex]
        .replaceAll(RegExp(r'^\\d+\\s'), '');

    print("Detected Sign: $detectedLabel");

    // Stability filter
    if (_lastLabel == detectedLabel) {

      _stableCount++;

    } else {

      _stableCount = 0;

      _lastLabel = detectedLabel;
    }

    // Require stable prediction
    if (_stableCount < 3) {
      return null;
    }

    return detectedLabel;
  }

  // ================= DISPOSE =================

  void dispose() {
    _interpreter?.close();
  }
}