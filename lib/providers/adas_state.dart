import 'package:flutter/material.dart';

class AdasState extends ChangeNotifier {
  bool isActive = false;

  // 🔥 ADD FEATURE FLAGS
  bool laneEnabled = true;
  bool collisionEnabled = true;
  bool drowsinessEnabled = true;
  bool trafficSignEnabled = true;
  bool potholeEnabled = true;

  void toggleAdas() {
    isActive = !isActive;
    notifyListeners();
  }

  // 🔥 ADD SETTERS
  void setLane(bool value) {
    laneEnabled = value;
    notifyListeners();
  }

  void setCollision(bool value) {
    collisionEnabled = value;
    notifyListeners();
  }

  void setDrowsiness(bool value) {
    drowsinessEnabled = value;
    notifyListeners();
  }

  void setTrafficSign(bool value) {
    trafficSignEnabled = value;
    notifyListeners();
  }

  void setPothole(bool value) {
    potholeEnabled = value;
    notifyListeners();
  }
}