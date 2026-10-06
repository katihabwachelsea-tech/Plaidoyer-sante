import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Zone de signature manuscrite pour le médecin.
/// - Fond blanc avec ligne de base
/// - Trait épais (3.5) et fluide avec lissage de courbe
/// - Bouton Effacer stylé + indicateur de statut
class SignaturePad extends StatefulWidget {
  final ValueChanged<String?>? onChanged;

  const SignaturePad({super.key, this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final _strokes = <List<Offset>>[];
  List<Offset> _current = [];
  final _repaintKey = GlobalKey();

  bool get hasStroke => _strokes.any((s) => s.isNotEmpty);

  void clear() {
    setState(() {
      _strokes.clear();
      _current = [];
    });
    widget.onChanged?.call(null);
  }

  Future<String?> toBase64Png() async {
    if (!hasStroke) return null;
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _current.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (_current.isNotEmpty) {
      setState(() {
        _strokes.add(List.from(_current));
        _current = [];
      });
      _notify();
    }
  }

  Future<void> _notify() async {
    final b64 = await toBase64Png();
    widget.onChanged?.call(b64);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Zone de dessin ────────────────────────────────────────────
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasStroke
                  ? const Color(0xFF0B6EBD)
                  : const Color(0xFFD1D5DB),
              width: hasStroke ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Indicateur de zone vide
                if (!hasStroke)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_rounded,
                            size: 36,
                            color: Colors.grey.withValues(alpha: 0.35)),
                        const SizedBox(height: 6),
                        Text(
                          'Signez ici',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Zone de capture
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        current: _current,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Barre de statut + bouton Effacer ─────────────────────────
        Row(
          children: [
            // Indicateur signé / non signé
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasStroke
                    ? const Color(0xFF0E9F6E).withValues(alpha: 0.10)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasStroke
                        ? Icons.verified_rounded
                        : Icons.edit_outlined,
                    size: 13,
                    color: hasStroke
                        ? const Color(0xFF0E9F6E)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasStroke ? 'Signé' : 'Non signé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasStroke
                          ? const Color(0xFF0E9F6E)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bouton Effacer
            OutlinedButton.icon(
              onPressed: hasStroke ? clear : null,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Effacer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE24B4A),
                side: BorderSide(
                  color: hasStroke
                      ? const Color(0xFFE24B4A)
                      : Colors.grey.shade300,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Painter avec lissage ─────────────────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;

  _SignaturePainter({required this.strokes, required this.current});

  static final _paint = Paint()
    ..color = const Color(0xFF1A1A2E)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    // Ligne de base
    final basePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(20, size.height * 0.72),
      Offset(size.width - 20, size.height * 0.72),
      basePaint,
    );

    // Tracé des strokes terminées
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    // Tracé en cours
    if (current.isNotEmpty) {
      _drawStroke(canvas, current);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      // Point unique → petit cercle
      canvas.drawCircle(pts[0], 1.8, _paint);
      return;
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length - 1; i++) {
      // Courbe de Bézier quadratique pour lisser
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      final midY = (pts[i].dy + pts[i + 1].dy) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, midX, midY);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      old.strokes != strokes || old.current != current;
}
