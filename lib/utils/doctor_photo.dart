import 'package:flutter/material.dart';

/// Photos iStock de médecins — mêmes URLs que la liste de référence.
/// Femmes pour prénoms féminins, hommes pour prénoms masculins.

const List<String> kFemaleDoctorPhotos = [
  'https://media.istockphoto.com/id/2185361097/photo/black-woman-doctor-and-smile-with-arms-crossed-at-hospital-for-medical-service-female-person.jpg?s=2048x2048&w=is&k=20&c=hLW5fqHCj4JgjJAf_0aafN6nFb9ZAQIrygmQknqgDMg=',
  'https://media.istockphoto.com/id/2050883733/photo/happy-successful-doctor-woman-medical-worker-in-white-lab-coat-standing-with-crossed-arms-on.jpg?s=170667a&w=0&k=20&c=xdOAJYw5TsS-khijd6Vri2aXStJG__6kcnaLtwzVnAA=',
  'https://media.istockphoto.com/id/171296819/photo/african-american-female-doctor-holding-a-clipboard-isolated.jpg?s=612x612&w=0&k=20&c=hCJk-9gsOff8Fac04a11VMOwflMYiRXUVfAj3UTn67U=',
  'https://media.istockphoto.com/id/171313563/photo/confident-african-american-female-doctor-isolated.jpg?s=612x612&w=0&k=20&c=2N6561X3mIMGbZAs32X97kwhm_4v2MZXwq_cBO2X_UI=',
];

const List<String> kMaleDoctorPhotos = [
  'https://media.istockphoto.com/id/1203995945/photo/portrait-of-mature-male-doctor-wearing-white-coat-standing-in-hospital-corridor.jpg?s=170667a&w=0&k=20&c=p-cciIWNGLWHc6N7T85rMmn2ynEIg0pD5NEnEO9qBu8=',
  'https://media.istockphoto.com/id/1390000431/photo/shot-of-a-mature-doctor-using-a-digital-tablet-in-a-modern-hospital.jpg?s=170667a&w=0&k=20&c=KLScLZH6NJw3m5GaFWngSzSTEmn0rE_0D-MSl772vQU=',
  'https://media.istockphoto.com/id/185288528/photo/smiling-african-american-male-doctor-isolated.jpg?s=612x612&w=0&k=20&c=JCCdlizGVIVlbv0yOA99T_lc9hg3Ms9LXC2WIjOiZzw=',
  'https://media.istockphoto.com/id/1372701329/photo/shot-of-a-young-male-doctor-standing-with-his-arms-crossed-in-an-office-at-a-hospital.jpg?s=612x612&w=0&k=20&c=6NEKvLXkwWsaCcWrI9CqhOBLxWVkDhH8JfVuy2WBaFk=',
];

const Set<String> kFemaleDoctorFirstNames = {
  'alice', 'aline', 'amina', 'angele', 'beatrice', 'bernadette',
  'brigitte', 'carine', 'cecile', 'chelsea', 'chantal', 'chloe',
  'christa', 'claire', 'claudine', 'diane', 'divine', 'emma',
  'esther', 'eunice', 'eve', 'fatoumata', 'felicite', 'flore',
  'flora', 'francoise', 'grace', 'gloire', 'helene', 'hope',
  'honorine', 'isabelle', 'jane', 'jeannette', 'jessica', 'joelle',
  'josephine', 'judith', 'julie', 'justine', 'karen', 'laure',
  'laurence', 'lea', 'linda', 'lisa', 'lucie', 'lydie',
  'madeleine', 'marcelline', 'marguerite', 'marie', 'mariette',
  'marina', 'martine', 'merveille', 'michelle', 'mireille', 'miriam',
  'monique', 'murielle', 'nadia', 'nadine', 'nathalie', 'nicole',
  'ornella', 'pascaline', 'patience', 'pauline', 'prisca',
  'prudence', 'rachel', 'regine', 'reine', 'rose', 'rosalie',
  'rosette', 'ruth', 'sabine', 'salome', 'sandrine', 'sarah',
  'simone', 'solange', 'sonia', 'sophia', 'sophie', 'stella',
  'stephanie', 'suzanne', 'tatiana', 'therese', 'valentina',
  'valerie', 'vanessa', 'veronique', 'victoire', 'virginie',
  'viviane', 'wivine', 'yvonne', 'zoe',
};

bool _isTrustedPhotoUrl(String url) {
  return url.contains('istockphoto.com') || url.contains('/storage/');
}

/// Photo de profil : garde iStock / upload, sinon fallback selon le genre du prénom.
String doctorPhotoUrl(dynamic doctor, {int index = 0}) {
  String? url;

  if (doctor is Map) {
    final userMap = doctor['user'];
    if (userMap is Map) {
      url = userMap['photo_url'] as String?;
      url ??= userMap['profileImageUrl'] as String?;
    }
    url ??= doctor['photo_url'] as String?;
    url ??= doctor['profileImageUrl'] as String?;
  }

  if (url != null && url.startsWith('http') && _isTrustedPhotoUrl(url)) {
    return url;
  }

  final name = doctor is Map
      ? (doctor['user']?['nom'] ?? doctor['nom'] ?? '').toString()
      : '';

  final photos =
      isFemaleDoctorName(name) ? kFemaleDoctorPhotos : kMaleDoctorPhotos;
  return photos[index % photos.length];
}

bool isFemaleDoctorName(String fullName) {
  final cleaned = fullName
      .trim()
      .replaceFirst(RegExp(r'^(dr\.?|docteur)\s+', caseSensitive: false), '');
  final first = cleaned.split(RegExp(r'[\s\-]+')).first.toLowerCase();
  return kFemaleDoctorFirstNames.contains(first);
}

String formatServicePrice(num? value) {
  if (value == null) return '—';
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${buf.toString()} FBu';
}

String serviceModeLabel(String? mode) {
  if (mode == 'teleconsultation') return 'Télé';
  return 'Cabinet';
}

/// Badges mode (présentiel / télé) + prix min sur une carte médecin.
class DoctorModePriceChips extends StatelessWidget {
  final Map doctor;

  const DoctorModePriceChips({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final modes = <String>{};
    final rawModes = doctor['modes'];
    if (rawModes is List) {
      for (final m in rawModes) {
        modes.add('$m');
      }
    }
    final services = doctor['services'];
    if (services is List) {
      for (final s in services) {
        if (s is Map && s['mode'] != null) modes.add('${s['mode']}');
      }
    }

    num? prixMin = doctor['prix_min'] is num
        ? doctor['prix_min'] as num
        : num.tryParse('${doctor['prix_min'] ?? ''}');
    if (prixMin == null && services is List) {
      for (final s in services) {
        if (s is Map) {
          final p = s['prix'] is num ? s['prix'] as num : num.tryParse('${s['prix']}');
          if (p != null && (prixMin == null || p < prixMin)) prixMin = p;
        }
      }
    }

    if (modes.isEmpty && prixMin == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (modes.contains('presentiel'))
          _chip('Cabinet', const Color(0xFF0E9F6E)),
        if (modes.contains('teleconsultation'))
          _chip('Télé', const Color(0xFF107ACA)),
        if (prixMin != null)
          _chip('dès ${formatServicePrice(prixMin)}', const Color(0xFF0B6EBD)),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Photo médecin cadrée sur le haut (visage) pour éviter les têtes coupées.
class DoctorPhotoImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const DoctorPhotoImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // Priorité au haut de la photo = visage visible
        alignment: const Alignment(0, -0.35),
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: const Color(0xFF0B6EBD).withValues(alpha: 0.10),
          child: Icon(
            Icons.person_rounded,
            color: const Color(0xFF0B6EBD),
            size: width * 0.45,
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFEEF3F8),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}
