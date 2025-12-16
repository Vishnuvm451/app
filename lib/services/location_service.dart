import 'package:geolocator/geolocator.dart';

class LocationService {
  // 🏫 College Location
  static const double collegeLat = 10.766056;
  static const double collegeLng = 76.406194;

  // Allowed radius (meters)
  static const double allowedRadius = 120;

  // --------------------------------------------------
  // CHECK & REQUEST PERMISSION
  // --------------------------------------------------
  static Future<void> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw "Location service disabled";
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw "Location permission denied";
    }
  }

  // --------------------------------------------------
  // GET CURRENT POSITION
  // --------------------------------------------------
  static Future<Position> getCurrentLocation() async {
    await checkPermission();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // --------------------------------------------------
  // CHECK IF INSIDE CAMPUS
  // --------------------------------------------------
  static bool isInsideCampus({
    required double studentLat,
    required double studentLng,
  }) {
    final double distance = Geolocator.distanceBetween(
      studentLat,
      studentLng,
      collegeLat,
      collegeLng,
    );

    return distance <= allowedRadius;
  }
}
