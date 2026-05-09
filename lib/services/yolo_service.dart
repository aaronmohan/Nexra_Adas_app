import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/yolo_preprocessor.dart';
import '../utils/yolo_postprocessor.dart';

class YoloService {
  late Interpreter _interpreter;
  bool _loaded = false;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      "assets/ml_models/yolov8n.tflite",
    );
    _loaded = true;
    print("YOLO model loaded");
  }

  bool get isLoaded => _loaded;

  Future<List<Detection>> detect(img.Image image) async {
    if (!_loaded) return [];

    final input = YoloPreprocessor.process(image);

    var output =
        List.generate(1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));

    _interpreter.run(input, output);

    // 🔁 TRANSPOSE OUTPUT (VERY IMPORTANT)
final transposed = List.generate(
  8400,
  (i) => List.generate(22, (j) => output[0][j][i]),
);

return YoloPostProcessor.process(
  transposed,
  image.width,
  image.height,
);
  }
}