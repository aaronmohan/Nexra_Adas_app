import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

img.Image convertCameraImage(CameraImage image) {
  final width = image.width;
  final height = image.height;

  final img.Image imgImage = img.Image(width: width, height: height);

  final plane = image.planes[0];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = plane.bytes[y * plane.bytesPerRow + x];
      imgImage.setPixelRgb(x, y, pixel, pixel, pixel);
    }
  }

  return imgImage;
}