// lib/services/prescription_pdf_service.dart
//
// Génère une ordonnance médicale en PDF et permet de la partager/télécharger.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrescriptionPdfService {
  PrescriptionPdfService._();

  /// Génère et affiche la prévisualisation PDF avec options partage/impression.
  static Future<void> previewAndShare({
    required BuildContext context,
    required Map<String, dynamic> record,
  }) async {
    final pdfBytes = await _generate(record);
    if (!context.mounted) return;

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: _fileName(record),
      format: PdfPageFormat.a4,
    );
  }

  /// Génère les bytes PDF sans affichage.
  static Future<Uint8List> generate(Map<String, dynamic> record) =>
      _generate(record);

  // ── Génération ────────────────────────────────────────────────────────

  static Future<Uint8List> _generate(Map<String, dynamic> record) async {
    final pdf = pw.Document();

    // Données de la consultation
    final appt        = record['appointment'] as Map<String, dynamic>?;
    final medecin     = appt?['medecin'] as Map<String, dynamic>?;
    final doctorUser  = medecin?['user'] as Map?;
    final doctorName  = (doctorUser?['nom'] ?? 'Médecin').toString();
    final specialite  = (medecin?['specialite'] ?? '').toString();
    final hopital     = (medecin?['hopital'] ?? '').toString();
    final telephone   = (doctorUser?['telephone'] ?? '').toString();

    final serviceMap  = appt?['service'] as Map?;
    final service     = (serviceMap?['nom_service'] ?? 'Consultation').toString();

    final diagnostic  = (record['diagnostic'] ?? '—').toString();
    final ordonnance  = (record['ordonnance'] ?? '—').toString();
    final anamnese    = (record['anamnese'] ?? '').toString();
    final examen      = (record['examen'] ?? '').toString();
    final conseils    = (record['conseils_ia'] ?? '').toString();

    var dateLabel = (record['date_consultation'] ?? '').toString();
    try {
      dateLabel = DateFormat('d MMMM yyyy', 'fr_FR').format(
        DateTime.parse(dateLabel.replaceFirst(' ', 'T')).toLocal(),
      );
    } catch (_) {}

    // Facture
    final invoice = appt?['invoice'] as Map?;
    final montant = invoice != null && invoice['montant'] != null
        ? '${invoice['montant']} FBu'
        : null;
    final txId = invoice?['transaction_id']?.toString();

    // Couleurs
    const primary = PdfColor.fromInt(0xFF107ACA);
    const grey    = PdfColor.fromInt(0xFF6B7280);
    const light   = PdfColor.fromInt(0xFFF4F8FB);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => _buildHeader(
          doctorName: doctorName,
          specialite: specialite,
          hopital: hopital,
          telephone: telephone,
          primary: primary,
          grey: grey,
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Mob-Clinic — Document confidentiel',
              style: pw.TextStyle(fontSize: 8, color: grey),
            ),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: grey),
            ),
          ],
        ),
        build: (_) => [
          _buildTitle(service, dateLabel, primary),
          pw.SizedBox(height: 16),

          if (anamnese.isNotEmpty) ...[
            _buildSection('Anamnèse', anamnese, light, grey),
            pw.SizedBox(height: 10),
          ],
          if (examen.isNotEmpty) ...[
            _buildSection('Examen clinique', examen, light, grey),
            pw.SizedBox(height: 10),
          ],

          _buildSection('Diagnostic', diagnostic, light, grey),
          pw.SizedBox(height: 10),

          _buildOrdonnanceBox(ordonnance, primary, light),
          pw.SizedBox(height: 10),

          if (conseils.isNotEmpty) ...[
            _buildSection('Notes / conseils', conseils, light, grey),
            pw.SizedBox(height: 10),
          ],

          if (montant != null) ...[
            pw.SizedBox(height: 6),
            _buildInvoiceLine(montant, txId, grey),
          ],

          pw.SizedBox(height: 40),
          _buildSignatureLine(doctorName, specialite, grey),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Widgets PDF ───────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required String doctorName,
    required String specialite,
    required String hopital,
    required String telephone,
    required PdfColor primary,
    required PdfColor grey,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                if (specialite.isNotEmpty)
                  pw.Text(specialite,
                      style: pw.TextStyle(fontSize: 11, color: grey)),
                if (hopital.isNotEmpty)
                  pw.Text(hopital,
                      style: pw.TextStyle(fontSize: 10, color: grey)),
                if (telephone.isNotEmpty)
                  pw.Text('Tél : $telephone',
                      style: pw.TextStyle(fontSize: 10, color: grey)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'ORDONNANCE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.Divider(color: primary, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildTitle(
      String service, String date, PdfColor primary) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          service,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: primary),
        ),
        pw.Text(
          'Date : $date',
          style: pw.TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  static pw.Widget _buildSection(
      String title, String content, PdfColor bg, PdfColor grey) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: grey),
          ),
          pw.SizedBox(height: 4),
          pw.Text(content,
              style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.justify),
        ],
      ),
    );
  }

  static pw.Widget _buildOrdonnanceBox(
      String ordonnance, PdfColor primary, PdfColor light) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: light,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PRESCRIPTION MÉDICALE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primary,
            ),
          ),
          pw.Divider(color: primary),
          pw.SizedBox(height: 4),
          pw.Text(
            ordonnance,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceLine(
      String montant, String? txId, PdfColor grey) {
    return pw.Row(
      children: [
        pw.Text('Consultation : ',
            style: pw.TextStyle(fontSize: 10, color: grey)),
        pw.Text(montant,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: grey)),
        if (txId != null) ...[
          pw.Text('  ·  Réf : ',
              style: pw.TextStyle(fontSize: 10, color: grey)),
          pw.Text(txId, style: pw.TextStyle(fontSize: 10, color: grey)),
        ],
      ],
    );
  }

  static pw.Widget _buildSignatureLine(
      String doctorName, String specialite, PdfColor grey) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 160,
              height: 1,
              color: grey,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            if (specialite.isNotEmpty)
              pw.Text(specialite,
                  style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.Text('Signature et cachet',
                style: pw.TextStyle(fontSize: 8, color: grey)),
          ],
        ),
      ],
    );
  }

  static String _fileName(Map<String, dynamic> record) {
    final appt = record['appointment'] as Map<String, dynamic>?;
    final medecin = appt?['medecin'] as Map<String, dynamic>?;
    final doctorUser = medecin?['user'] as Map?;
    final doctor = (doctorUser?['nom'] ?? 'medecin')
        .toString()
        .toLowerCase()
        .replaceAll(' ', '_');
    var dateStr = '';
    try {
      dateStr = DateFormat('yyyyMMdd').format(
        DateTime.parse(
            (record['date_consultation'] ?? '').toString().replaceFirst(' ', 'T')),
      );
    } catch (_) {}
    return 'ordonnance_${doctor}_$dateStr.pdf';
  }
}
