import 'package:flutter/material.dart';

import '../../models/dash_telemetry.dart';
import '../../models/vehicle_type.dart';

class VehicleOutline extends StatelessWidget {
  const VehicleOutline({
    super.key,
    required this.vehicleType,
    required this.tires,
  });

  final VehicleType vehicleType;
  final TirePressures tires;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 120,
      child: CustomPaint(
        painter: _VehicleOutlinePainter(
          vehicleType: vehicleType,
          tires: tires,
        ),
      ),
    );
  }
}

class _VehicleOutlinePainter extends CustomPainter {
  _VehicleOutlinePainter({
    required this.vehicleType,
    required this.tires,
  });

  final VehicleType vehicleType;
  final TirePressures tires;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.9);

    final body = Path();
    if (vehicleType == VehicleType.motorcycle) {
      body.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.35, size.height * 0.18, size.width * 0.3,
              size.height * 0.55),
          const Radius.circular(8),
        ),
      );
    } else {
      body.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.28, size.height * 0.12, size.width * 0.44,
              size.height * 0.72),
          const Radius.circular(10),
        ),
      );
    }
    canvas.drawPath(body, stroke);

    final green = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF66BB6A);
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.32),
      Offset(size.width * 0.28, size.height * 0.58),
      green,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.32),
      Offset(size.width * 0.72, size.height * 0.58),
      green,
    );

    void label(Offset at, double v) {
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label(Offset(size.width * 0.12, size.height * 0.28), tires.frontLeft);
    label(Offset(size.width * 0.88, size.height * 0.28), tires.frontRight);
    label(Offset(size.width * 0.12, size.height * 0.72), tires.rearLeft);
    label(Offset(size.width * 0.88, size.height * 0.72), tires.rearRight);
  }

  @override
  bool shouldRepaint(covariant _VehicleOutlinePainter oldDelegate) {
    return oldDelegate.vehicleType != vehicleType || oldDelegate.tires != tires;
  }
}