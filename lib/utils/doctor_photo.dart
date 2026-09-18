/// Photos iStock de médecins — mêmes URLs que la liste de référence.
/// Femmes pour prénoms féminins, hommes pour prénoms masculins.
/// Les noms des médecins ne sont pas modifiés.

const List<String> kFemaleDoctorPhotos = [
  // Dr. Christa Kwizera
  'https://media.istockphoto.com/id/2185361097/photo/black-woman-doctor-and-smile-with-arms-crossed-at-hospital-for-medical-service-female-person.jpg?s=2048x2048&w=is&k=20&c=hLW5fqHCj4JgjJAf_0aafN6nFb9ZAQIrygmQknqgDMg=',
  // Dr. Alice Nyiransabimana
  'https://media.istockphoto.com/id/2050883733/photo/happy-successful-doctor-woman-medical-worker-in-white-lab-coat-standing-with-crossed-arms-on.jpg?s=170667a&w=0&k=20&c=xdOAJYw5TsS-khijd6Vri2aXStJG__6kcnaLtwzVnAA=',
  // Dr. Laure Niyonkuru
  'https://media.istockphoto.com/id/171296819/photo/african-american-female-doctor-holding-a-clipboard-isolated.jpg?s=612x612&w=0&k=20&c=hCJk-9gsOff8Fac04a11VMOwflMYiRXUVfAj3UTn67U=',
  // Dr. Mireille Uwimana
  'https://media.istockphoto.com/id/171313563/photo/confident-african-american-female-doctor-isolated.jpg?s=612x612&w=0&k=20&c=2N6561X3mIMGbZAs32X97kwhm_4v2MZXwq_cBO2X_UI=',
];

const List<String> kMaleDoctorPhotos = [
  // Dr. Jean-Paul Hakizimana
  'https://media.istockphoto.com/id/1203995945/photo/portrait-of-mature-male-doctor-wearing-white-coat-standing-in-hospital-corridor.jpg?s=170667a&w=0&k=20&c=p-cciIWNGLWHc6N7T85rMmn2ynEIg0pD5NEnEO9qBu8=',
  // Dr. Emmanuel Ndayishimiye
  'https://media.istockphoto.com/id/1390000431/photo/shot-of-a-mature-doctor-using-a-digital-tablet-in-a-modern-hospital.jpg?s=170667a&w=0&k=20&c=KLScLZH6NJw3m5GaFWngSzSTEmn0rE_0D-MSl772vQU=',
  // Dr. Patrick Nsengiyumva
  'https://media.istockphoto.com/id/185288528/photo/smiling-african-american-male-doctor-isolated.jpg?s=612x612&w=0&k=20&c=JCCdlizGVIVlbv0yOA99T_lc9hg3Ms9LXC2WIjOiZzw=',
  // Dr. Hassan Mpawenimana
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
