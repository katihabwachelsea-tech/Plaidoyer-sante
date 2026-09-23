// lib/services/ai_chat_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/patient.dart';
import '../services/db_service.dart'; // <--- CETTE LIGNE EST ESSENTIELLE

class AIChatService {
  static final AIChatService instance = AIChatService._internal();
  AIChatService._internal();

  // Clé Gemini : passer --dart-define=GEMINI_API_KEY=votre_cle
  // Fallback démo si non fournie (à remplacer en prod).
  static const String _PLACEHOLDER_KEY = 'YOUR_GEMINI_API_KEY';
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBl_pn4qPsGPf-JBPt68ix3l5_cuVeks4s',
  );

  bool get hasApiKey => _apiKey.isNotEmpty && _apiKey != _PLACEHOLDER_KEY;

  // late final GenerativeModel _model;
  GenerativeModel? _model; // MODIFIÉ : Rendu optionnel
  // late final ChatSession _chatSession;
  ChatSession? _chatSession; // MODIFIÉ : Rendu optionnel
  Patient? _currentPatient;

  // Initialiser le chat pour un patient spécifique
  void initializeChat(Patient patient) {
    // _currentPatient = patient;

    // _model = GenerativeModel(
    //   model: 'gemini-pro',
    //   apiKey: _apiKey,
    //   generationConfig: GenerationConfig(
    //     temperature: 0.7,
    //     topK: 40,
    //     topP: 0.95,
    //     maxOutputTokens: 1024,
    //   ),
    // );
    // Vérifie si la session est déjà initialisée pour ce patient
    if (_currentPatient != null &&
        _currentPatient!.id == patient.id &&
        _chatSession != null) {
      return; // Ne fait rien si c'est le même patient et la session est active
    }

    _currentPatient = patient;

    // 💡 S'assurer que _model est initialisé une seule fois pour tous les patients
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );
    }

    // Contexte initial du patient pour l'IA
    final systemPrompt =
        '''
Tu es un **Co-Pilote d'Aide à la Décision Clinique**. Tu assistes un médecin dans la prise en charge d'un patient donné.
Informations du patient actuel :
- Nom : ${patient.nomComplet}
- Âge : ${patient.age} ans
- Pays : ${patient.pays}
- Diagnostic : ${patient.maladie}
- Conseils actuels : ${patient.conseils ?? 'Aucun'}

Consignes IMPORTANTES :
1. Réponds TOUJOURS au **médecin** qui est ton interlocuteur.
2. Fournis des **recommandations professionnelles et factuelles** basées sur le profil du patient.
3. Réfère-toi au patient en utilisant "le patient" ou son nom, pas "vous".
4.Adapte tes réponses à ${patient.maladie} et au contexte africain (${patient.pays}).
5. Limite tes réponses à 3-4 phrases maximum.
6. Ne donne jamais de diagnostic, mais des pistes de conseils.
7. Reste dans ton domaine médical, ne réponds pas aux questions hors sujet


Tu es prêt à assister le médecin dans la prise en charge de ce patient.''';

    _chatSession = _model!.startChat(
      history: [
        Content.text(systemPrompt),
        Content.model([
          TextPart(
            // Nouvelle réponse de l'IA après le prompt système
            'Je suis en ligne. Contexte du patient **${patient.nomComplet}** chargé. Quelle est votre question clinique, Docteur ?',
          ),
        ]),
      ],
    );
  }

  // Envoyer un message au chatbot
  Future<ChatResponse> sendMessage(String userMessage) async {
    if (_currentPatient == null) {
      throw Exception(
        'Chat non initialisé. Appelez initializeChat() d\'abord.',
      );
    }

    if (_apiKey == _PLACEHOLDER_KEY) {
      // Mode offline - réponses prédéfinies
      return _getOfflineResponse(userMessage);
    }

    try {
      print('👤 User: $userMessage');

      final content = Content.text(userMessage);
      final response = await _chatSession!.sendMessage(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Réponse vide de l\'IA');
      }

      print('🤖 AI: ${response.text}');

      return ChatResponse(
        message: response.text!,
        isFromUser: false,
        timestamp: DateTime.now(),
        source: MessageSource.ai,
      );
    } catch (e) {
      print('❌ Erreur chat IA: $e');
      return _getOfflineResponse(userMessage);
    }
  }

  // Réponses offline basées sur mots-clés (VERSION COMPLÈTE ET CORRIGÉE)
 ChatResponse _getOfflineResponse(String userMessage) {
 final lowerMessage = userMessage.toLowerCase();
 String response;

 // Récupérer les infos du patient pour le contexte
 final patientDisease = _currentPatient!.maladie;
 final patientName = _currentPatient!.prenom; 

// Détection par mots-clés
 if (lowerMessage.contains('médicament') ||
 lowerMessage.contains('medicament') ||
 lowerMessage.contains('traitement') ||
 lowerMessage.contains('posologie')) {
 response =
 '**Concernant le traitement de ${patientDisease}** : Rappelez à ${patientName} l\'importance d\'une prise régulière et du respect strict de la posologie. Insistez pour qu\'il ne suspende jamais le traitement sans votre avis. En cas d\'oubli, suivre la procédure habituelle.';
 } else if (lowerMessage.contains('manger') ||
 lowerMessage.contains('aliment') ||
 lowerMessage.contains('nutrition') ||
 lowerMessage.contains('nourriture')) {
 response =
 '**Recommandations nutritionnelles pour ${patientDisease}** : Conseillez d\'orienter ${patientName} vers des fruits frais, des légumes locaux et des aliments non transformés. L\'hydratation est cruciale. Une diète équilibrée est un soutien thérapeutique essentiel.';
 } else if (lowerMessage.contains('douleur') ||
 lowerMessage.contains('mal') ||
 lowerMessage.contains('souffrance') ||
 lowerMessage.contains('symptôme')) { 
 response =
 '**Gestion de la douleur/des symptômes** : Il est recommandé d\'instruire ${patientName} à noter l\'intensité et la fréquence des douleurs. Si la douleur persiste ou est aiguë, demandez-lui de vous reconsulter immédiatement.Évitez l\'automédication pour la douleur.'; 
 } else if (lowerMessage.contains('exercice') ||
 lowerMessage.contains('sport') ||
 lowerMessage.contains('activité')) {
 response =
 '**Activité physique** : Pour ${patientDisease}, conseillez une activité physique modérée (ex: marche quotidienne de 20-30 min) si l\'état du patient le permet. Insistez sur l\'écoute du corps et l\'évitement des efforts intenses sans évaluation préalable.';
 } else if (lowerMessage.contains('fatigue') ||
 lowerMessage.contains('fatigué') ||
 lowerMessage.contains('énergie')) {
 response =
 '**Gestion de la fatigue** : La fatigue est fréquente. Recommandez à ${patientName} un sommeil de qualité (7-8h) et de courtes siestes. Suggérez un bilan nutritionnel si la fatigue est chronique et excessive afin d\'écarter toute cause métabolique traitable.'; 
 } else if (lowerMessage.contains('stress') ||
 lowerMessage.contains('anxiété') ||
 lowerMessage.contains('peur') ||
 lowerMessage.contains('inquiet')) {
 response =
 '**Support psychologique et Stress** : Le bien-être mental est primordial. Conseillez des techniques de relaxation ou de respiration profonde, et encouragez ${patientName} à se confier à son entourage ou à un professionnel de la santé mentale si le stress est sévère.'; 
 } else if (lowerMessage.contains('urgence') ||
 lowerMessage.contains('grave') ||
 lowerMessage.contains('danger')) {
 response =
 '🚨 **Procédure d\'urgence** : Rappelez au patient que tout symptôme aigu (difficulté respiratoire, douleur thoracique, saignement incontrôlé, etc.) nécessite un transfert **IMMEDIAT** vers une structure de soins d\'urgence. Ce co-pilote ne remplace pas une évaluation d\'urgence.';
 } else {
 response =
 'Je n\'ai pas trouvé de protocole précis en mode hors-ligne pour cela, Docteur. Je peux vous assister avec des conseils sur les **médicaments**, l\'**alimentation**, l\'**exercice**, ou la **gestion de la fatigue** pour ${patientDisease}.'; 
 }

    return ChatResponse(
      message: response,
      isFromUser: false,
      timestamp: DateTime.now(),
      source: MessageSource.local,
    );
  }

  // =======================================================================
  // NOUVELLE MÉTHODE POUR GÉNÉRER LES CONSEILS (REMPLACE L'ANCIENNE)
  // =======================================================================
  Future<AdviceResponse> generateAdvice(Patient patient) async {
    if (_apiKey == 'AIzaSyA9KlGdCICCiPJS9YAHu_8P2JXXix_vUQw') {
      print('🔧 Mode offline : Utilisation des conseils locaux.');
      return _getLocalAdviceFallback(patient); // Appel de la méthode renommée
    }

    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

    final prompt =
        '''
      Génère une liste de 4 conseils de santé courts, pratiques et faciles à suivre pour un patient avec le profil suivant :
      - Diagnostic : ${patient.maladie}
      - Âge : ${patient.age} ans
      - Pays : ${patient.pays}
      Instructions :
      1. Les conseils doivent être directement applicables dans un contexte africain (${patient.pays}).
      2. Formule chaque conseil en une seule phrase simple.
      3. Retourne UNIQUEMENT la liste des conseils, sans introduction ni conclusion.
      4. Sépare chaque conseil par un retour à la ligne.
      ''';

    try {
      print(' Envoi de la requête de conseils à l\'IA...');
      final content = Content.text(prompt);
      final response = await model.generateContent([content]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Réponse vide de l\'IA');
      }

      final adviceList = response.text!
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.startsWith('- ') ? s.substring(2) : s)
          .toList();

      print('✅ Conseils IA reçus : ${adviceList.length} éléments');

      patient.conseils = adviceList.join('\n');
      await DatabaseService.instance.updatePatient(patient);

      // Ici, on appelle le constructeur de la classe AdviceResponse, c'est correct
      return AdviceResponse(advice: adviceList, source: MessageSource.ai);
    } catch (e) {
      print('❌ Erreur lors de la génération de conseils IA: $e');
      return _getLocalAdviceFallback(patient); // Appel de la méthode renommée
    }
  }


 // =======================================================================
 // MÉTHODE RENOMMÉE POUR ÉVITER LE CONFLIT (ADAPTÉE POUR LE RÔLE DU MÉDECIN)
 // =======================================================================
AdviceResponse _getLocalAdviceFallback(Patient patient) {
    List<String> advice;
    final lowerDisease = patient.maladie.toLowerCase();

    if (lowerDisease.contains('diabète')) {
      advice = [
        'Rappeler au patient de **contrôler sa glycémie** chaque jour avant le petit-déjeuner.',
        'Recommander une **marche** de 30 minutes au moins 5 fois par semaine pour améliorer la sensibilité à l\'insuline.',
        'Conseiller de privilégier les aliments locaux riches en fibres (manioc/igname) et d\'**éviter les sucres rapides**.',
        'Insister sur l\'importance de boire beaucoup d\'eau pure et d\'**éliminer les boissons sucrées** industrielles.',
      ];
    } else if (lowerDisease.contains('hypertension')) {
      advice = [
        'Suggérer une **réduction drastique de la consommation de sel** (y compris les cubes de bouillon et condiments industriels).',
        'Encourager l\'ingestion de fruits riches en potassium comme la banane pour aider à **réguler la tension artérielle**.',
        'Prescrire des techniques de **détente quotidienne** (respiration, méditation) pour gérer le stress.',
        'Souligner l\'observance stricte du traitement : **prise quotidienne à heure fixe**, même en cas de bien-être apparent.',
      ];
    } else {
      advice = [
        'Suggérer un objectif d\'**hydratation** d\'au moins 1.5 litre d\'eau par jour.',
        'Vérifier la qualité et la quantité du **sommeil** (cible : 7 à 8 heures par nuit).',
        'Encourager des repas équilibrés incluant des **légumes et fruits locaux** à chaque prise.',
        'Rappeler la nécessité de **consulter avant toute nouvelle prise de médicament** ou de complément alimentaire.',
      ];
    }

    patient.conseils = advice.join('\n');
    DatabaseService.instance.updatePatient(patient);

    return AdviceResponse(advice: advice, source: MessageSource.local);
  }

  // Suggestions de questions
  List<String> getSuggestedQuestions() {
    if (_currentPatient == null) return [];
    // Utiliser _currentPatient! pour accéder aux données du patient
    final patientName = _currentPatient!.nomComplet;
    final disease = _currentPatient!.maladie;
   return [
    'Quelle est la posologie habituelle pour ${disease} ?',
    'Quels sont les principaux conseils nutritionnels pour ${patientName} ?',
    'Comment gérer un pic de symptômes chez ce patient ?',
    'Y a-t-il des interactions médicamenteuses courantes à éviter ?',
    'Quelle routine d\'exercice puis-je recommander au patient ?',
    'Quels sont les signes d\'alerte pour une urgence ?',
 ];
  }

  // Obtenir l'historique du chat
  int getMessageCount() {
    return 0; // Placeholder
  }

  // Réinitialiser le chat
  void resetChat() {
    if (_currentPatient != null) {
      initializeChat(_currentPatient!);
    }
  }
}

// Modèle pour les réponses du chat
class ChatResponse {
  final String message;
  final bool isFromUser;
  final DateTime timestamp;
  final MessageSource source;

  ChatResponse({
    required this.message,
    required this.isFromUser,
    required this.timestamp,
    required this.source,
  });
}

// Modèle pour le retour des conseils (correspond à 'result')
class AdviceResponse {
  final List<String> advice;
  final MessageSource source;

  AdviceResponse({required this.advice, required this.source});
}

enum MessageSource {
  ai, // Réponse de l'IA Gemini
  local, // Réponse locale prédéfinie
  user, // Message de l'utilisateur
}
