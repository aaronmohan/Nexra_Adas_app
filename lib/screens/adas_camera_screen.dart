

import 'package:provider/provider.dart';
import '../providers/adas_state.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/lane_detection_service.dart';
import '../services/collision_logic_service.dart';
import '../services/light_collision_service.dart';
import '../services/traffic_sign_service.dart';
import '../models/traffic_sign_detection.dart';
import '../services/drowsiness_detection_service.dart';
import '../widgets/adas_overlay.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
//import '../utils/yolo_decoder.dart';
import '../services/yolo_service.dart';
//import '../utils/yolo_preprocessor.dart';
import '../utils/image_converter.dart';
import '../utils/yolo_postprocessor.dart';



class ADASCameraScreen extends StatefulWidget {
  const ADASCameraScreen({super.key});

  @override
  State<ADASCameraScreen> createState() => _ADASCameraScreenState();
}

class _ADASCameraScreenState extends State<ADASCameraScreen>
    with WidgetsBindingObserver {

  CameraController? _cameraController;
  String? _detectedSign;
  DateTime? _lastSignTime;
  bool _isCameraInitialized = false;
  bool _servicesInitialized = false;
  bool _isProcessing = false;

  // Camera switching
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isFrontCamera = false;

  // Drowsiness detection
  late DrowsinessService _drowsinessService;
  bool _isDrowsy = false;
  bool _wasDrowsy = false;
  List<Face> _faces = [];

  // ⚡ Performance control
  int _drowsinessFrameSkip = 0;

  bool _laneDetected = false;
  bool _laneDepartureDetected = false;
  double _laneOffset = 0.0;
  TrafficSignDetection? _trafficSign;
  

  //late final AudioPlayer _audioPlayer;
  late YoloService yoloService;
  late final AudioPlayer _lanePlayer;
  late final AudioPlayer _collisionPlayer;

  //Interpreter? _collisionInterpreter;
  //int _frameCounter = 0; // for performance control

  bool _collisionSoundPlaying = false;
  CollisionLevel _lastCollisionLevel = CollisionLevel.safe;//newly added for warning alert

  final TrafficSignService _trafficService = TrafficSignService();

  bool trafficSignDetected = false;
  int frameCount = 0;

  

//FeatureMode currentMode = FeatureMode.lane;

  //late YoloPreprocessor yoloPreprocessor;

  @override
  void initState() {
    super.initState();
    _trafficService.init();
    WidgetsBinding.instance.addObserver(this);

    yoloService = YoloService();
   // yoloPreprocessor = YoloPreprocessor();
    yoloService.loadModel();
    //_audioPlayer = AudioPlayer();
    _lanePlayer = AudioPlayer();
    _collisionPlayer = AudioPlayer();
    _drowsinessService = DrowsinessService(); 

  Future.microtask(() async {
    await _initializeServices();
    await _initializeCamera();
  });
}


  Future<void> _initializeServices() async {
      //_collisionInterpreter = await Interpreter.fromAsset(//
      //'assets/ml_models/yolov8s_int8.tflite',                //
     // options: InterpreterOptions()..threads = 4,          //
    //);//modified for collision
    setState(() {
      _servicesInitialized = true;
    });
    //print("INPUT SHAPE: ${_collisionInterpreter!.getInputTensor(0).shape}");
    //print("INPUT TYPE: ${_collisionInterpreter!.getInputTensor(0).type}");
  }

  Future<void> _initializeCamera() async {
     _cameras = await availableCameras();
    _selectedCameraIndex = 1; //front camera by default
    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.low,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    _isFrontCamera =
    _cameras![_selectedCameraIndex].lensDirection ==
        CameraLensDirection.front;

    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
    });

    _startImageStream();
  }

  Future<void> _switchCamera() async {
  if (_cameras == null || _cameras!.length < 2) return;

  _selectedCameraIndex =
      _selectedCameraIndex == 0 ? 1 : 0;

  await _cameraController?.dispose();

  _cameraController = CameraController(
    _cameras![_selectedCameraIndex],
    ResolutionPreset.low,
    enableAudio: false,
  );

  await _cameraController!.initialize();

  _isFrontCamera =
      _cameras![_selectedCameraIndex].lensDirection ==
          CameraLensDirection.front;

  _startImageStream();

  setState(() {});
}

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      await _processFrame(image);

      _isProcessing = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
  if (!_servicesInitialized) return;

  final adas = context.read<AdasState>();

  frameCount++;

  // If system OFF → do nothing
  if (!adas.isActive) return;

  // Convert once for YOLO
  final imgImage = convertCameraImage(image);

  // OBJECT DETECTION (YOLO)
  List<Detection> detections = [];
  if (adas.collisionEnabled || adas.trafficSignEnabled) {
    detections = await yoloService.detect(imgImage);

    // Example usage (you can modify this)
    for (final obj in detections) {
      final classId = obj.classId;
      final confidence = obj.score;

      final x1 = obj.x1;
      final y1 = obj.y1;
      final x2 = obj.x2;
      final y2 = obj.y2;

      final width = x2 - x1;
      final height = y2 - y1;

      // Debug print
      print("Detected: class=$classId conf=$confidence");
    }
  }

  // 😴 DROWSINESS (front camera only)
  if (_isFrontCamera && adas.drowsinessEnabled) {
    if (frameCount % 3 == 0) {
      await _runDrowsiness(image); // CameraImage ✅
    }
    return;
  }

  // 🚗 LANE DETECTION (CameraImage)
  if (adas.laneEnabled) {
    await _runLane(image); // ✅ FIXED
  }

  // 🚨 COLLISION (CameraImage)
  if (adas.collisionEnabled && frameCount % 3 == 0) {
    await _runCollision(image);
  }

  // 🚸 TRAFFIC SIGN (CameraImage)
  if (adas.trafficSignEnabled && frameCount % 5 == 0) {
    await _runTrafficSign(image);
  }
}

Future<void> _runLane(CameraImage image) async {
  final laneService = context.read<LaneDetectionService>();

  final result = await laneService.detectLanes(image);

  setState(() {
    _laneDetected = result;
    _laneDepartureDetected = laneService.laneDepartureDetected;
    _laneOffset = laneService.lastOffset;
  });

  if (_laneDepartureDetected) {
    await _playBeep();
  }
}

Future<void> _runDrowsiness(CameraImage image) async {
  final inputImage = _convertToInputImage(image);

  final faces = await _drowsinessService.detectFaces(inputImage);

  setState(() {
    _faces = faces;
  });

  final drowsy = _drowsinessService.checkDrowsiness(faces);

  setState(() {
    _isDrowsy = drowsy;
  });

  /// ✅ TRIGGER ALERT ONLY ON CHANGE
    if (drowsy && !_wasDrowsy) {
      await _lanePlayer.stop(); // ensure clean playback
      await _lanePlayer.play(
        AssetSource("sounds/warn.mp3"),
        volume: 1.0,
      );
    } else if (!drowsy && _wasDrowsy) {
      await _lanePlayer.stop();
    } 

    _wasDrowsy = drowsy;
}

Future<void> _runCollision(CameraImage image) async {
  final adas = context.read<AdasState>();

  if (!adas.collisionEnabled) return;

  final imgImage = convertCameraImage(image);
  final detections = await yoloService.detect(imgImage);

  bool collision = false;

  for (var obj in detections) {
    final classId = obj.classId;
    final confidence = obj.score;

    final x1 = obj.x1;
    final y1 = obj.y1;
    final x2 = obj.x2;
    final y2 = obj.y2;

final width = x2 - x1;
final height = y2 - y1;

    // 🚗 Vehicle classes (COCO)
    if (classId == 2 || classId == 5 || classId == 7) {
      if (width > 0.35) {
        collision = true;
        break;
      }
    }
  }

  // 🚨 Trigger alert
  if (collision) {
    await _collisionPlayer.play(
      AssetSource("sounds/warn.mp3"),
    );
  } else {
    await _collisionPlayer.stop();
  }
}

Future<void> _runTrafficSign(CameraImage image) async {

  print("TRAFFIC FUNCTION CALLED");

  // Convert camera image
  final convertedImage =
      _convertYUV420toImage(image);

  print(
    "Image size: ${convertedImage.width} x ${convertedImage.height}",
  );

  // STEP 1 → Extract sign region
  final croppedSign =
      _trafficService.extractSign(convertedImage);

  // No sign region found
  if (croppedSign == null) {

    // Keep old label visible for 3 seconds
    if (_lastSignTime != null &&
        DateTime.now().difference(_lastSignTime!) <
            const Duration(seconds: 3)) {

      return;
    }

    setState(() {
      _detectedSign = null;
    });

    return;
  }

  print(
    "Sign cropped: ${croppedSign.width} x ${croppedSign.height}",
  );

  // STEP 2 → Classify cropped sign
  final result =
      _trafficService.detect(croppedSign);

  // STEP 3 → Update UI
  if (result != null) {

    _lastSignTime = DateTime.now();

    setState(() {
      _detectedSign = result;
    });

  } else {

    // Keep label visible briefly
    if (_lastSignTime != null &&
        DateTime.now().difference(_lastSignTime!) <
            const Duration(seconds: 3)) {

      return;
    }

    setState(() {
      _detectedSign = null;
    });
  }

  print("Detected Sign: $result");
}

  Future<void> _playBeep() async {
      await _lanePlayer.setReleaseMode(ReleaseMode.stop);
      await _lanePlayer.play(
        AssetSource("sounds/beep.mp3"),
        volume: 0.8,
      );
    }

    Future<void> _handleCollisionSound(CollisionLevel level) async {
        if (level == _lastCollisionLevel) return;

        _lastCollisionLevel = level;

        await _collisionPlayer.stop();

        if (level == CollisionLevel.warning) {
          await _collisionPlayer.setReleaseMode(ReleaseMode.loop);
          await _collisionPlayer.play(
            AssetSource("sounds/warn.mp3"),
            volume: 0.7,
          );
        } 
        else if (level == CollisionLevel.danger) {
          await _collisionPlayer.setReleaseMode(ReleaseMode.loop);
          await _collisionPlayer.play(
            AssetSource("sounds/warn.mp3"),
            volume: 1.0,
          );
        } 
        else {
          await _collisionPlayer.stop();
        }
      }


   

    img.Image _convertYUV420toImage(CameraImage image) {
      final width = image.width;
      final height = image.height;

      final img.Image imgBuffer = img.Image(width: width, height: height);

      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {

          final int yIndex = y * image.planes[0].bytesPerRow + x;
          final int uvIndex =
              (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final int yp = yPlane[yIndex];
          final int up = uPlane[uvIndex];
          final int vp = vPlane[uvIndex];

          int r = (yp + 1.402 * (vp - 128)).round();
          int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
          int b = (yp + 1.772 * (up - 128)).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgBuffer.setPixelRgba(x, y, r, g, b,255);
        }
      }

      return imgBuffer;
    }

  InputImage _convertToInputImage(CameraImage image) {
  final WriteBuffer allBytes = WriteBuffer();

  for (final plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }

  final bytes = allBytes.done().buffer.asUint8List();

  final imageSize = Size(
    image.width.toDouble(),
    image.height.toDouble(),
  );

  final camera = _cameras![_selectedCameraIndex];

  final rotation = _isFrontCamera
      ? InputImageRotation.rotation270deg
      : InputImageRotation.rotation90deg;

  final inputImageFormat =
      InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.yuv420;

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null ||
        !_isCameraInitialized ||
        !_servicesInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController!),

      /// ✅ ADD FACE DETECTION HERE (JUST BELOW CAMERA)

    ..._faces.map((face) {
      final rect = face.boundingBox;

      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width + 50,
        height: rect.height + 50,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "L: ${(face.leftEyeOpenProbability ?? 0).toStringAsFixed(2)}",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
              Text(
                "R: ${(face.rightEyeOpenProbability ?? 0).toStringAsFixed(2)}",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }).toList(),

    if (_isDrowsy)
  Positioned(
    top: 50,
    left: 20,
    right: 20,
    child: Container(
      padding: EdgeInsets.all(12),
      color: Colors.red.withOpacity(0.8),
      child: Text(
        "DROWSINESS DETECTED 🚨",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    ),
  ),



          /// TRAFFIC SIGN BOUNDING BOX
      if (_detectedSign != null)
  Positioned(
    top: 120,
    left: 20,
    right: 20,
    child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        children: [

          const Icon(
            Icons.traffic,
            color: Colors.orange,
            size: 30,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              "SIGN: $_detectedSign",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  ),


          ADASOverlay(
            laneDetected: _laneDetected,
            laneDepartureDetected: _laneDepartureDetected,
            laneOffset: _laneOffset,
            //collisionWarning: null,
            drowsinessDetected: _isDrowsy,
            trafficSignDetected: _detectedSign,
            potholeDetected: false,
            isDriverFacing: false,
          ),
          /// 🆕 Collision Warning Overlay (NEW)
      Consumer<CollisionLogicService>(
        builder: (context, service, child) {

          if (service.level == CollisionLevel.safe) {
            return const SizedBox.shrink();
          }

          final isDanger =
              service.level == CollisionLevel.danger;

          return Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDanger
                    ? Colors.red.withOpacity(0.9)
                    : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Text(
                isDanger
                    ? "⚠ IMMEDIATE COLLISION RISK"
                    : "⚠ Vehicle Too Close",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),

         /// Camera Switch Button
Positioned(
  bottom: 100,
  right: 20,
  child: FloatingActionButton(
    heroTag: "switchCameraBtn",
    onPressed: _switchCamera,
    child: const Icon(Icons.cameraswitch),
  ),
),

/// Back Button
Positioned(
  bottom: 30,
  left: 0,
  right: 0,
  child: Center(
    child: FloatingActionButton(
      heroTag: "backBtn",
      onPressed: () => Navigator.pop(context),
      child: const Icon(Icons.arrow_back),
    ),
  ),
),
    ],
  ),
);
  }

 

  @override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);

  if (_cameraController != null) {
     _cameraController!.stopImageStream();
     _cameraController!.dispose();
  }

  //_collisionInterpreter?.close();
  _lanePlayer.dispose();
  _collisionPlayer.dispose();

  super.dispose();
}
}