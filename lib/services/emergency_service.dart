import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyService {

  Future<bool> sendEmergencyAlert(String phoneNumber) async {

    try {

      // ================= PERMISSION =================

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {

        print("Location permission denied");
        return false;
      }

      // ================= LOCATION =================

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latitude = position.latitude;
      final longitude = position.longitude;

      final mapsLink =
          "https://maps.google.com/?q=$latitude,$longitude";

      // ================= MESSAGE =================

      final message =
          "🚨 EMERGENCY ALERT!\n"
          "User may be in danger.\n"
          "Live Location:\n$mapsLink";

      // ================= SMS =================

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {
            'body': message,
        },
        );

        await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
        );

        print("Emergency SMS opened");

        return true;

    } catch (e) {

      print("Emergency error: $e");
      return false;
    }
  }
}