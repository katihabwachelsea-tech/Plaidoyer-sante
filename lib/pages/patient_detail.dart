// lib/pages/patient_detail_page.dart

import 'package:flutter/material.dart';
import '../models/patient.dart'; // Assurez-vous d'importer votre modèle Patient
// import '../utils/constants.dart' as constants; // Pour les couleurs et tailles
import '../widgets/metric_card.dart';
import '../models/Conseil.dart'; // 1. Import du modèle Conseil
import '../services/sync_service_hybrid.dart';
import '../services/ai_chat_service.dart'; // 2. Import du service DB
import '../services/db_service.dart';
// import 'utils/constants.dart';
import '../pages/ai_chat_page.dart';

// Définition des constantes pour les couleurs et tailles (pour l'exemple)
// class AppColors {
//   static const Color primary = Colors.blue;
//   static const Color textPrimary = Colors.black;
//   static const Color textSecondary = Colors.grey;
//   static const Color background = Color(0xFFF5F5F5);
// }

// class AppSizes {
//   static const double paddingS = 8.0;
//   static const double paddingM = 12.0;
//   static const double paddingL = 16.0;
//   static const double paddingXL = 24.0;
// }

// 1. CHANGEMENT EN STATEFULWIDGET
// ----------------------------------------------------

class PatientDetailPage extends StatefulWidget {
  final Patient patient;

  const PatientDetailPage({Key? key, required this.patient}) : super(key: key);

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  // --- Propriétés de l'IA/Conseils existantes
  bool _isGeneratingAdvice = false;
  List<String> _aiAdvice = [];
  MessageSource? _adviceSource;
  late Patient _currentPatient;

  // --- NOUVELLES PROPRIÉTÉS POUR L'ÉDITION ---
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _ageController;
  late TextEditingController _paysController;
  late TextEditingController _maladieController;
  late TextEditingController _conseilsController;
  // Note: Pour une gestion complète des dates et autres types,
  // il faudrait plus de champs et de logique de conversion.

  @override
  void initState() {
    super.initState();
    // Initialisation du patient actuel pour les modifications
    _currentPatient = widget.patient;

    // Initialisation des contrôleurs de texte avec les valeurs actuelles
    _nomController = TextEditingController(text: _currentPatient.nom);
    _prenomController = TextEditingController(text: _currentPatient.prenom);
    _ageController =
        TextEditingController(text: _currentPatient.age.toString());
    _paysController = TextEditingController(text: _currentPatient.pays);
    _maladieController = TextEditingController(text: _currentPatient.maladie);
    _conseilsController = TextEditingController(text: _currentPatient.statut);

    if (_currentPatient.conseils != null) {
      _aiAdvice = _currentPatient.conseils!
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      AIChatService.instance.initializeChat(_currentPatient);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _ageController.dispose();
    _paysController.dispose();
    _maladieController.dispose();
    _conseilsController.dispose();
    super.dispose();
  }

  // --- LOGIQUE D'ÉDITION/SAUVEGARDE ---

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;

      // Si on quitte le mode édition sans sauvegarder, on réinitialise les champs.
      if (!_isEditing) {
        _nomController.text = _currentPatient.nom;
        _prenomController.text = _currentPatient.prenom;
        _ageController.text = _currentPatient.age.toString();
        _paysController.text = _currentPatient.pays;
        _maladieController.text = _currentPatient.maladie;
        _conseilsController.text = _currentPatient.statut;
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        // Crée une nouvelle instance de Patient avec les données du formulaire
        final updatedPatient = _currentPatient.copyWith(
          nom: _nomController.text,
          prenom: _prenomController.text,
          age: int.tryParse(_ageController.text) ?? _currentPatient.age,
          pays: _paysController.text,
          maladie: _maladieController.text,
          conseils: _conseilsController.text,
          // Les autres champs comme 'id', 'derniereVisite', 'conseils'
          // sont conservés via copyWith si non spécifiés
        );

        // Appel au service pour mettre à jour en base de données
        await SyncServiceHybrid.instance.updatePatient(updatedPatient);

        setState(() {
          _currentPatient = updatedPatient;
          _isEditing = false; // Quitter le mode édition
        });

        // Afficher un message de succès (le "token") et revenir à la liste
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Patient mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        // Utiliser `pop` pour revenir à la page précédente (PatientsListPage)
        // en signalant que la liste doit être rafraîchie (si nécessaire)
        Navigator.pop(context, true); 

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de la sauvegarde: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MÉTHODES EXISTANTES ---

  Future<void> _generateAIAdvice() async {
    setState(() {
      _isGeneratingAdvice = true;
    });

    try {
      final result = await AIChatService.instance.generateAdvice(
        widget.patient,
      );

      // Met à jour le patient dans l'état local pour refléter les nouveaux conseils
      final patientWithAdvice = _currentPatient.copyWith(
        conseils: result.advice.join('\n'),
      );
      await DatabaseService.instance.updatePatient(patientWithAdvice);
      _currentPatient = patientWithAdvice;


      setState(() {
        _aiAdvice = result.advice;
        _adviceSource = result.source;
        _isGeneratingAdvice = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // On vérifie si la source est l'IA pour déterminer le succès
            result.source == MessageSource.ai
                ? '✨ Conseils IA générés avec succès !'
                : '📋 Conseils locaux chargés',
          ),
          backgroundColor:
              result.source == MessageSource.ai ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _isGeneratingAdvice = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Générer une couleur basée sur le nom
  Color _getPatientColor() {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];
    final index = _currentPatient.nom.hashCode % colors.length;
    return colors[index.abs()];
  }

  // --- NOUVEAU WIDGET : Champs de Texte en Mode Édition
  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer le $label';
              }
              return null;
            },
      ),
    );
  }

  // --- WIDGET D'AFFICHAGE DU DÉTAIL (non modifiable)
  Widget _buildDetailSection(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL BUILD ---

  @override
  Widget build(BuildContext context) {
    final patientColor = _getPatientColor();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar avec photo du patient
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: patientColor,
            flexibleSpace: FlexibleSpaceBar(
              title: _isEditing
                  ? const Text('Édition Patient',
                      style: TextStyle(color: Colors.white, fontSize: 18))
                  : null,
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [patientColor, patientColor.withOpacity(0.8)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Photo du patient avec bordure
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: Text(
                          _currentPatient.prenom[0].toUpperCase() +
                              _currentPatient.nom[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: patientColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nom du patient
                    Text(
                      _currentPatient.nomComplet,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Badge statut
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentPatient.statut,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Bouton Édition / Sauvegarde
              IconButton(
                icon: Icon(
                    _isEditing ? Icons.save : Icons.edit, color: Colors.white),
                onPressed: () {
                  if (_isEditing) {
                    _saveChanges(); // Si en mode édition, on sauvegarde
                  } else {
                    _toggleEditMode(); // Sinon, on passe en mode édition
                  }
                },
              ),
              if (_isEditing) // Bouton Annuler en mode édition
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleEditMode,
                ),
            ],
          ),

          // Contenu principal
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // Contenu principal: DÉTAIL ou FORMULAIRE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isEditing
                    ? Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildEditableField(
                              controller: _nomController,
                              label: 'Nom',
                              icon: Icons.person_outline,
                            ),
                            _buildEditableField(
                              controller: _prenomController,
                              label: 'Prénom',
                              icon: Icons.person_outline,
                            ),
                            _buildEditableField(
                              controller: _ageController,
                              label: 'Âge',
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer l\'âge';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'L\'âge doit être un nombre';
                                }
                                return null;
                              },
                            ),
                            _buildEditableField(
                              controller: _paysController,
                              label: 'Pays',
                              icon: Icons.public_outlined,
                            ),
                            _buildEditableField(
                              controller: _maladieController,
                              label: 'Diagnostic / Maladie',
                              icon: Icons.medical_services_outlined,
                            ),
                            _buildEditableField(
                              controller: _conseilsController,
                              label: 'conseils',
                              icon: Icons.info_outline,
                            ),
                            const SizedBox(height: 20),
                            // Le bouton de sauvegarde est dans l'AppBar, mais on peut
                            // en ajouter un ici aussi pour plus de visibilité
                            ElevatedButton.icon(
                              onPressed: _saveChanges,
                              icon: const Icon(Icons.save),
                              label: const Text('Sauvegarder les modifications'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cartes d'informations rapides (inchangées)
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickInfoCard(
                                  icon: Icons.cake,
                                  label: 'Âge',
                                  value: '${_currentPatient.age} ans',
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickInfoCard(
                                  icon: Icons.public,
                                  label: 'Pays',
                                  value: _currentPatient.pays,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Carte maladie (inchangée)
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.medical_services,
                                      color: Colors.red.shade400,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Diagnostic',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentPatient.maladie,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dernière visite (inchangée)
                          if (_currentPatient.derniereVisite != null) ...[
                            const SizedBox(height: 12),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: Colors.purple.shade400,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Dernière visite',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_currentPatient.derniereVisite!.day}/${_currentPatient.derniereVisite!.month}/${_currentPatient.derniereVisite!.year}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Il y a ${DateTime.now().difference(_currentPatient.derniereVisite!).inDays} jours',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Le reste des sections (IA Chat et Conseils) n'est affiché qu'en mode Détail
              if (!_isEditing) ...[
                // Section Actions IA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Assistant Médical IA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bouton Chat IA - DESIGN AMÉLIORÉ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AIChatPage(patient: _currentPatient),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Poser une question',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Discutez avec l\'assistant IA 24/7',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Bouton Conseils automatiques
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingAdvice ? null : _generateAIAdvice,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.blue.shade300, width: 2),
                    ),
                    icon: _isGeneratingAdvice
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGeneratingAdvice
                          ? 'Génération en cours...'
                          : 'Générer conseils personnalisés',
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Section Conseils
                if (_aiAdvice.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Conseils Personnalisés',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_adviceSource != null)
                          Chip(
                            label: Text(
                              _adviceSource == MessageSource.ai
                                  ? '🤖 IA'
                                  : '📋 Local',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: _adviceSource == MessageSource.ai
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: _aiAdvice.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade400,
                                          Colors.blue.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  // Widget utilitaire inchangé
  Widget _buildQuickInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}