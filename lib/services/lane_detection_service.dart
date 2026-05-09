import 'package:camera/camera.dart';

class LaneDetectionService {
  bool _laneDepartureDetected = false;
  double _lastOffset = 0.0;
  DateTime? _lastDepartureTime;

  final double _departureThreshold = 0.15;
  final Duration _cooldown = const Duration(seconds: 2);

  // ================= MAIN API =================

  Future<bool> detectLanes(CameraImage image) async {
    try {
      final width = image.width;
      final height = image.height;

      final bytes = image.planes[0].bytes;

      // Only process bottom 40% of image
      final startY = (height * 0.6).toInt();

      int lanePixelCount = 0;
      double weightedXSum = 0;

      // Sample every 4 pixels for performance
      for (int y = startY; y < height; y += 4) {
          for (int x = (width * 0.2).toInt(); x < (width * 0.8).toInt(); x += 4) {
          final index = y * width + x;
          if (index >= bytes.length) continue;

          final pixel = bytes[index];

          // Bright pixel threshold (detect white lines)
          if (pixel > 200 && pixel < 255) {

            // Check neighbor pixel (simple edge check)
            final rightIndex = y * width + (x + 2 < width ? x + 2 : x);
            final rightPixel = bytes[rightIndex];

            if ((pixel - rightPixel).abs() > 15) {
              lanePixelCount++;
              weightedXSum += x;
            }
          }
        }
      }

      if (lanePixelCount == 0) {
        _laneDepartureDetected = false;
        _lastOffset = 0.0;
        return false;
      }

      final avgX = weightedXSum / lanePixelCount;

      final rawOffset =
    (avgX / (width - 1)) * 2 - 1;

        // Smooth using previous value
        final normalizedOffset =
            (_lastOffset * 0.7) + (rawOffset * 0.3);

      _detectDeparture(normalizedOffset);

      return true;
    } catch (e) {
      print("Lane detection error: $e");
      return false;
    }
  }

  // ================= DEPARTURE LOGIC =================

  void _detectDeparture(double currentOffset) {
    final delta =
        (currentOffset - _lastOffset).abs();

    final now = DateTime.now();

    final cooledDown = _lastDepartureTime == null ||
        now.difference(_lastDepartureTime!) > _cooldown;

    if (delta > _departureThreshold && cooledDown) {
      _laneDepartureDetected = true;
      _lastDepartureTime = now;
      print(
          "🚨 Lane Departure | Offset: ${currentOffset.toStringAsFixed(2)}");
    } else {
      _laneDepartureDetected = false;
    }

    _lastOffset = currentOffset;
  }

  // ================= GETTERS =================

  bool get laneDepartureDetected =>
      _laneDepartureDetected;

  double get lastOffset => _lastOffset;

  void dispose() {}
}