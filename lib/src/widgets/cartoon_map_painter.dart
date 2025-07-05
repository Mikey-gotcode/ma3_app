// lib/src/pages/role_pages/admin_home_page.dart
import 'package:flutter/material.dart';
// Import for Timer
// Import for random numbers

// --- Vehicle Model ---
class Vehicle {
  final String id;
  Offset position; // Current position on the map (relative to painter's canvas)
  final Color color;
  final IconData icon; // For representing the vehicle visually
  // You can add more properties like speed, destination, etc.

  Vehicle({
    required this.id,
    required this.position,
    required this.color,
    this.icon = Icons.directions_car, // Default car icon
  });
}

// --- CartoonMapPainter: Draws the custom map and vehicles ---
class CartoonMapPainter extends CustomPainter {
  final List<Vehicle> vehicles; // List of vehicles to draw
  final double animationValue; // Value from 0.0 to 1.0 for animation progress

  CartoonMapPainter({required this.vehicles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Define some basic colors for our cartoon map
    final Paint roadPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.fill;
    final Paint grassPaint = Paint()
      ..color = Colors.lightGreen[400]!
      ..style = PaintingStyle.fill;
    final Paint buildingPaint = Paint()
      ..color = Colors.brown[400]!
      ..style = PaintingStyle.fill;
    final Paint windowPaint = Paint()
      ..color = Colors.lightBlue[200]!
      ..style = PaintingStyle.fill;

    // Draw background (grass)
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), grassPaint);

    // Draw some simple roads (example: a cross shape)
    // Horizontal road
    canvas.drawRect(
        Rect.fromLTWH(0, size.height / 2 - 20, size.width, 40), roadPaint);
    // Vertical road
    canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - 20, 0, 40, size.height), roadPaint);

    // Draw some simple cartoon buildings
    // Building 1 (top-left)
    canvas.drawRect(Rect.fromLTWH(50, 50, 80, 100), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(60, 60, 20, 20), windowPaint); // Window
    canvas.drawRect(Rect.fromLTWH(90, 60, 20, 20), windowPaint); // Window

    // Building 2 (bottom-right)
    canvas.drawRect(Rect.fromLTWH(size.width - 130, size.height - 150, 100, 100), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(size.width - 120, size.height - 140, 20, 20), windowPaint);
    canvas.drawRect(Rect.fromLTWH(size.width - 90, size.height - 140, 20, 20), windowPaint);
    canvas.drawRect(Rect.fromLTWH(size.width - 120, size.height - 110, 20, 20), windowPaint);

    // Draw vehicles
    for (var vehicle in vehicles) {
      // Use TextPainter to draw an IconData as text
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(vehicle.icon.codePoint),
          style: TextStyle(
            fontSize: 30, // Size of the icon
            fontFamily: vehicle.icon.fontFamily,
            color: vehicle.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Calculate position to center the icon on the vehicle's position
      final Offset offset = Offset(
        vehicle.position.dx - textPainter.width / 2,
        vehicle.position.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);

      // Optionally, draw a circle behind the icon for more cartoonish effect
      canvas.drawCircle(vehicle.position, 20, Paint()..color = vehicle.color.withOpacity(0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Only repaint if vehicles or animation value changes
    return (oldDelegate as CartoonMapPainter).vehicles != vehicles ||
           (oldDelegate).animationValue != animationValue;
  }
}