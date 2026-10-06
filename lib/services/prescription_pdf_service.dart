// lib/services/prescription_pdf_service.dart
//
// Génère une ordonnance médicale en PDF A4.
// Utilise les médicaments structurés (medicaments JSON) si disponibles,
// sinon replie sur le champ ordonnance texte.
// Intègre l'image de signature depuis signature_path (URL serveur).

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';

class PrescriptionPdfService {
  PrescriptionPdfService._();

  /// Génère et ouvre la prévisualisation PDF (partage / impression).
  static Future<void> previewAndShare({
    required BuildContext context,
    required Map<String, dynamic> record,
  }) async {
    final pdfBytes = await generate(record);
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: _fileName(record),
      format: PdfPageFormat.a4,
    );
  }

  /// Retourne les bytes PDF sans affichage.
  static Future<Uint8List> generate(Map<String, dynamic> record) =>
      _generate(record);

  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> _generate(Map<String, dynamic> record) async {
    final pdf = pw.Document(compress: true);

    // ── Données médecin ───────────────────────────────────────────────────
    final appt       = record['appointment'] as Map<String, dynamic>?;
    final medecin    = appt?['medecin'] as Map<String, dynamic>?;
    final docUser    = medecin?['user'] as Map?;
    final doctorName = (docUser?['nom'] ?? record['medecin'] ?? 'Médecin').toString();
    final specialite = (medecin?['specialite'] ?? '').toString();
    final hopital    = (medecin?['hopital'] ?? '').toString();
    final telephone  = (docUser?['telephone'] ?? '').toString();

    // ── Données service & patient ─────────────────────────────────────────
    final serviceMap = appt?['service'] as Map?;
    final service    = (serviceMap?['nom_service'] ?? 'Consultation').toString();
    final motif      = (appt?['motif'] ?? '').toString();

    // ── Médicaments structurés ou texte brut ──────────────────────────────
    final medsRaw    = record['medicaments'];
    final List<Map<String, dynamic>> meds = medsRaw is List
        ? medsRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
    final ordonnanceTxt = (record['ordonnance'] ?? '').toString();

    // ── SOAP résumé ───────────────────────────────────────────────────────
    final diagnostic = (record['diagnostic'] ?? '—').toString();
    final soapA      = (record['soap_a'] ?? '').toString();

    // ── Date ──────────────────────────────────────────────────────────────
    var dateLabel = (record['date_consultation'] ?? '').toString();
    try {
      dateLabel = DateFormat('d MMMM yyyy · HH:mm', 'fr_FR').format(
        DateTime.parse(dateLabel.replaceFirst(' ', 'T')).toLocal(),
      );
    } catch (_) {}

    // ── Facture ───────────────────────────────────────────────────────────
    final invoice = appt?['invoice'] as Map?;
    final montant = (invoice?['montant'] != null)
        ? '${invoice!['montant']} FBu'
        : null;
    final txId = invoice?['transaction_id']?.toString();

    // ── Signature image (depuis signature_path serveur) ───────────────────
    pw.MemoryImage? signatureImage;
    final sigPath = record['signature_path']?.toString() ?? '';
    if (sigPath.isNotEmpty) {
      try {
        final sigUrl = sigPath.startsWith('http')
            ? sigPath
            : '${AppConfig.baseUrl.replaceAll('/api', '')}$sigPath';
        final res = await http.get(Uri.parse(sigUrl))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          signatureImage = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    // ── Couleurs PDF ──────────────────────────────────────────────────────
    const cPrimary = PdfColor.fromInt(0xFF0B6EBD);
    const cGrey    = PdfColor.fromInt(0xFF6B7280);
    const cLight   = PdfColor.fromInt(0xFFF0F7FF);
    const cBorder  = PdfColor.fromInt(0xFFE1E8ED);
    const cBlack   = PdfColor.fromInt(0xFF1F2933);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (_) => _header(
          doctorName: doctorName, specialite: specialite,
          hopital: hopital, telephone: telephone,
          primary: cPrimary, grey: cGrey,
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Mob-Clinic · Document confidentiel',
                style: pw.TextStyle(fontSize: 7, color: cGrey)),
            pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: cGrey)),
          ],
        ),
        build: (_) => [
          // ── Titre ───────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(service,
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold,
                          color: cPrimary)),
                  if (motif.isNotEmpty)
                    pw.Text('Motif : $motif',
                        style: pw.TextStyle(fontSize: 10, color: cGrey)),
                ],
              ),
              pw.Text('Date : $dateLabel',
                  style: pw.TextStyle(fontSize: 9, color: cGrey)),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── Diagnostic ───────────────────────────────────────────────
          _section('Diagnostic', diagnostic, cLight, cGrey, cBorder),
          pw.SizedBox(height: 10),

          // ── Assessment / Analyse clinique ────────────────────────────
          if (soapA.isNotEmpty) ...[
            _section('Analyse clinique', soapA, cLight, cGrey, cBorder),
            pw.SizedBox(height: 10),
          ],

          // ── Médicaments ───────────────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: cPrimary, width: 1.5),
              borderRadius: pw.BorderRadius.circular(6),
              color: const PdfColor.fromInt(0xFFF8FBFF),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PRESCRIPTION MÉDICALE',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold,
                        color: cPrimary)),
                pw.Divider(color: cPrimary, thickness: 1),
                pw.SizedBox(height: 6),

                if (meds.isNotEmpty)
                  ...meds.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    final nom       = m['nom']?.toString() ?? '—';
                    final type      = m['type']?.toString() ?? '';
                    final generique = m['generique']?.toString() ?? '';
                    final dosage    = m['dosage']?.toString() ?? '';
                    final unite     = m['unite']?.toString() ?? '';
                    final freq      = m['frequence']?.toString() ?? '';
                    final prise     = m['prise']?.toString() ?? '';
                    final duree     = m['duree']?.toString() ?? '';
                    final uDuree    = m['unite_duree']?.toString() ?? '';
                    final instruc   = m['instructions']?.toString() ?? '';

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: cBorder),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Nom + numéro
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 20, height: 20,
                                decoration: pw.BoxDecoration(
                                  color: cPrimary,
                                  shape: pw.BoxShape.circle,
                                ),
                                child: pw.Center(
                                  child: pw.Text('${i + 1}',
                                      style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold)),
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                child: pw.Text(
                                  generique.isNotEmpty
                                      ? '$nom ($generique)'
                                      : nom,
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: cBlack),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          // Détails sur 2 lignes propres
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 28),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (type.isNotEmpty || dosage.isNotEmpty)
                                  pw.Text(
                                    [
                                      if (type.isNotEmpty) type,
                                      if (dosage.isNotEmpty && unite.isNotEmpty) '$dosage $unite',
                                    ].join(' · '),
                                    style: pw.TextStyle(fontSize: 10, color: cGrey),
                                  ),
                                if (freq.isNotEmpty || prise.isNotEmpty)
                                  pw.Text(
                                    [
                                      if (freq.isNotEmpty) 'Fréquence : $freq',
                                      if (prise.isNotEmpty) 'Prise : $prise',
                                    ].join('   '),
                                    style: pw.TextStyle(fontSize: 10, color: cGrey),
                                  ),
                                if (duree.isNotEmpty)
                                  pw.Text('Durée : $duree $uDuree',
                                      style: pw.TextStyle(fontSize: 10, color: cGrey)),
                                if (instruc.isNotEmpty)
                                  pw.Text('Note : $instruc',
                                      style: pw.TextStyle(
                                          fontSize: 10,
                                          color: const PdfColor.fromInt(0xFFE67E22),
                                          fontStyle: pw.FontStyle.italic)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  // Fallback texte brut — nettoyé des caractères problématiques
                  pw.Text(
                    ordonnanceTxt.replaceAll('\r', '').trim(),
                    style: pw.TextStyle(fontSize: 11, color: cBlack, lineSpacing: 4),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Facture ──────────────────────────────────────────────────
          if (montant != null)
            pw.Row(children: [
              pw.Text('Consultation : ',
                  style: pw.TextStyle(fontSize: 9, color: cGrey)),
              pw.Text(montant,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold, color: cGrey)),
              if (txId != null) ...[
                pw.Text('   Réf : $txId',
                    style: pw.TextStyle(fontSize: 9, color: cGrey)),
              ],
            ]),

          pw.SizedBox(height: 32),

          // ── Signature ────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 180,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Image de signature si disponible
                    if (signatureImage != null)
                      pw.Container(
                        height: 60,
                        child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.SizedBox(height: 40),

                    pw.Container(
                      width: 180, height: 1,
                      color: cGrey,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold,
                          color: cBlack),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (specialite.isNotEmpty)
                      pw.Text(specialite,
                          style: pw.TextStyle(fontSize: 9, color: cGrey),
                          textAlign: pw.TextAlign.center),
                    pw.Text('Signature et cachet',
                        style: pw.TextStyle(
                            fontSize: 8, color: cGrey,
                            fontStyle: pw.FontStyle.italic),
                        textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header page ───────────────────────────────────────────────────────────
  static pw.Widget _header({
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
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                  style: pw.TextStyle(
                      fontSize: 17, fontWeight: pw.FontWeight.bold,
                      color: primary),
                ),
                if (specialite.isNotEmpty)
                  pw.Text(specialite,
                      style: pw.TextStyle(fontSize: 10, color: grey)),
                if (hopital.isNotEmpty)
                  pw.Text(hopital,
                      style: pw.TextStyle(fontSize: 10, color: grey)),
                if (telephone.isNotEmpty)
                  pw.Text('Tél : $telephone',
                      style: pw.TextStyle(fontSize: 9, color: grey)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('ORDONNANCE',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: primary, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Section générique ─────────────────────────────────────────────────────
  static pw.Widget _section(
    String title, String content,
    PdfColor bg, PdfColor grey, PdfColor border,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: grey)),
          pw.SizedBox(height: 4),
          pw.Text(
            content.replaceAll('\r', '').trim(),
            style: pw.TextStyle(fontSize: 11, lineSpacing: 3),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  // ── Nom de fichier ────────────────────────────────────────────────────────
  static String _fileName(Map<String, dynamic> record) {
    final appt = record['appointment'] as Map<String, dynamic>?;
    final med  = appt?['medecin'] as Map<String, dynamic>?;
    final docU = med?['user'] as Map?;
    final doc  = (docU?['nom'] ?? record['medecin'] ?? 'medecin')
        .toString().toLowerCase().replaceAll(' ', '_');
    var dateStr = '';
    try {
      dateStr = DateFormat('yyyyMMdd').format(
        DateTime.parse(
            (record['date_consultation'] ?? '').toString().replaceFirst(' ', 'T')),
      );
    } catch (_) {}
    return 'ordonnance_${doc}_$dateStr.pdf';
  }
}
