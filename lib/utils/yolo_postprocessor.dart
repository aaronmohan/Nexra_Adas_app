import 'dart:math';

class Box {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  Box(this.x1, this.y1, this.x2, this.y2);

  double iou(Box other) {
    final double xLeft = x1 > other.x1 ? x1 : other.x1;
    final double yTop = y1 > other.y1 ? y1 : other.y1;
    final double xRight = x2 < other.x2 ? x2 : other.x2;
    final double yBottom = y2 < other.y2 ? y2 : other.y2;

    if (xRight < xLeft || yBottom < yTop) return 0.0;

    final intersection =
        (xRight - xLeft) * (yBottom - yTop);

    final area1 = (x2 - x1) * (y2 - y1);
    final area2 =
        (other.x2 - other.x1) *
        (other.y2 - other.y1);

    return intersection / (area1 + area2 - intersection);
  }
}

/// Single detection result
class Detection {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final Box box;
  final int classId;
  final double score;

  Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.box,
    required this.classId,
    required this.score,
  });
}

/// Simple rectangle class
class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;

  double iou(Rect other) {
    final x1 = max(left, other.left);
    final y1 = max(top, other.top);
    final x2 = min(right, other.right);
    final y2 = min(bottom, other.bottom);

    final intersection =
        max(0, x2 - x1) * max(0, y2 - y1);
    final union =
        width * height + other.width * other.height - intersection;

    return union == 0 ? 0 : intersection / union;
  }
}

class YoloPostProcessor {
  static const int inputSize = 640;
  static const int numClasses = 80;

  static const double confidenceThreshold = 0.4;
  static const double iouThreshold = 0.45;

  /// Main function
  static List<Detection> process(
    List<List<double>> output,
    int imageWidth,
    int imageHeight) {

  List<Detection> detections = [];

  for (final row in output) {
    if (row.length < 22) continue;

    double cx = row[0];
    double cy = row[1];
    double w = row[2];
    double h = row[3];

    double objectness = row[4];

    if (objectness < confidenceThreshold) continue;

    double maxClassScore = 0;
    int classId = -1;

    for (int i = 0; i < numClasses; i++) {
      double classScore = row[5 + i];
      if (classScore > maxClassScore) {
        maxClassScore = classScore;
        classId = i;
      }
    }

    double score = objectness * maxClassScore;
    if (score < confidenceThreshold) continue;

    double x1 = (cx - w / 2) * imageWidth / inputSize;
    double y1 = (cy - h / 2) * imageHeight / inputSize;
    double x2 = (cx + w / 2) * imageWidth / inputSize;
    double y2 = (cy + h / 2) * imageHeight / inputSize;

    final box = Box(x1, y1, x2, y2);

    detections.add(
      Detection(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        box: box,
        classId: classId,
        score: score,
      ),
    );
  }

  return _nms(detections);
}

  /// Non-Max Suppression
  static List<Detection> _nms(List<Detection> boxes) {
    boxes.sort((a, b) => b.score.compareTo(a.score));

    List<Detection> selected = [];

    for (final box in boxes) {
      bool keep = true;
      for (final picked in selected) {
        if (box.box.iou(picked.box) > iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) selected.add(box);
    }
    return selected;
  }
}
