import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DrowsinessService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // ------------------- EYE LOGIC -------------------
  int _closedEyeFrames = 0;
  final int thresholdFrames = 12; 

  // ------------------- YAWN LOGIC -------------------
  int _yawnFrames = 0;
  final int yawnThreshold = 4;

  /// Detect faces
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  /// Check drowsiness
  bool checkDrowsiness(List<Face> faces) {

  if (faces.isEmpty) {

    _closedEyeFrames = 0;
    return false;
  }

  final face = faces.first;

  // Eye probabilities
  final left = face.leftEyeOpenProbability ?? 1.0;
  final right = face.rightEyeOpenProbability ?? 1.0;

  print("LEFT EYE: $left");
  print("RIGHT EYE: $right");

  // Ignore bad detections
  if (left == 1.0 && right == 1.0) {
    return false;
  }

  // More realistic threshold
  bool eyesClosed = (left < 0.20 && right < 0.20);

  if (eyesClosed) {

    _closedEyeFrames++;

  } else {

    if (_closedEyeFrames > 0) {
      _closedEyeFrames--;
    }
  }

  print("Closed Frames: $_closedEyeFrames");

  // Require sustained closure
  bool eyeDrowsy = _closedEyeFrames >= 12;

  return eyeDrowsy;
}

  void dispose() {
    _faceDetector.close();
  }
}