// lib/widgets/gs_vehicle_pin.dart
// El conductor en el mapa: un círculo de marca con la moto o el taxi en
// blanco y borde blanco, como el carrito de Uber o la moto de InDrive.
// Se dibuja una vez como PNG para Google Maps y como widget en el respaldo.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

IconData vehicleIcon(String service) =>
    service == 'taxi' ? Icons.local_taxi_rounded : Icons.two_wheeler_rounded;

const double vehiclePinSize = 40;

class GSVehiclePin extends StatelessWidget {
  const GSVehiclePin({super.key, required this.service, this.size = vehiclePinSize});
  final String service;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GSColors.brand,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.08),
        boxShadow: GSShadow.float,
      ),
      child: Icon(vehicleIcon(service), color: GSColors.onBrand, size: size * 0.52),
    );
  }
}

Future<Uint8List> renderVehiclePin(String service,
    {required double pixelRatio, required Color brand}) async {
  final s = vehiclePinSize * pixelRatio;
  final pad = 3 * pixelRatio;
  final w = s + pad * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, w));
  final c = Offset(w / 2, w / 2);
  final r = s / 2;
  canvas.drawCircle(
      c + Offset(0, pixelRatio),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * pixelRatio));
  canvas.drawCircle(c, r, Paint()..color = Colors.white);
  canvas.drawCircle(c, r - s * 0.08, Paint()..color = brand);
  final icon = vehicleIcon(service);
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: s * 0.52,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  final image = await recorder.endRecording().toImage(w.ceil(), w.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
