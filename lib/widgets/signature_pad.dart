import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Zone de signature manuscrite pour le médecin.
class SignaturePad extends StatefulWidget {
  final ValueChanged<String?>? onChanged;

  const SignaturePad({super.key, this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final _points = <Offset?>[];
  final _repaintKey = GlobalKey();
  bool get hasStroke => _points.any((p) => p != null);

  void clear() {
    setState(() => _points.clear());
    widget.onChanged?.call(null);
  }

  Future<String?> toBase64Png() async {
    if (!hasStroke) return null;
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    return base64Encode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E8ED)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GestureDetector(
              onPanStart: (d) => setState(() => _points.add(d.localPosition)),
              onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
              onPanEnd: (_) {
                setState(() => _points.add(null));
                _notify();
              },
              child: RepaintBoundary(
                key: _repaintKey,
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }

  Future<void> _notify() async {
    final b64 = await toBase64Png();
    widget.onChanged?.call(b64);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F2933)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
