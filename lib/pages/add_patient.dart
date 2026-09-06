// lib/pages/add_patient.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import '../utils/constants.dart';
import '../models/patient.dart';
import '../services/sync_service_hybrid.dart';
import '../widgets/metric_card.dart';
import '../services/db_service.dart';

class AddPatientPage extends StatefulWidget {
  final Patient? patient; // Pour l'édition (null si nouveau patient)

  const AddPatientPage({super.key, this.patient});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _ageController = TextEditingController();
  final _conseilsController = TextEditingController();

  String? _selectedPays;
  String? _selectedMaladie;
  DateTime? _derniereVisite;
  bool _isLoading = false;

  // Liste des pays
  final List<String> _paysList = [
    'Burundi',
    'Rwanda',
    'RDC',
    'Tanzanie',
    'Kenya',
    'Ouganda',
    'Autre',
  ];

  // Liste des maladies
  final List<String> _maladiesList = [
    'Cancer du sein',
    'Cancer du poumon',
    'Cancer colorectal',
    'Cancer de la prostate',
    'Cancer de l\'estomac',
    'Cancer du foie',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    // Si on modifie un patient existant, pré-remplir les champs
    if (widget.patient != null) {
      _nomController.text = widget.patient!.nom;
      _prenomController.text = widget.patient!.prenom;
      _ageController.text = widget.patient!.age.toString();
      _selectedPays = widget.patient!.pays;
      _selectedMaladie = widget.patient!.maladie;
      _conseilsController.text = widget.patient!.conseils ?? '';
      _derniereVisite = widget.patient!.derniereVisite;
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _ageController.dispose();
    _conseilsController.dispose();
    super.dispose();
  }

  // Validation du nom/prénom
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName est requis';
    }
    if (value.trim().length < 2) {
      return '$fieldName doit contenir au moins 2 caractères';
    }
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s-]+$').hasMatch(value)) {
      return '$fieldName ne doit contenir que des lettres';
    }
    return null;
  }

  // Validation de l'âge
  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'âge est requis';
    }
    final age = int.tryParse(value);
    if (age == null) {
      return 'L\'âge doit être un nombre';
    }
    if (age < 0 || age > 150) {
      return 'L\'âge doit être entre 0 et 150 ans';
    }
    return null;
  }

  // Validation du pays
  String? _validatePays(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez sélectionner un pays';
    }
    return null;
  }

  // Validation de la maladie
  String? _validateMaladie(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez sélectionner une maladie';
    }
    return null;
  }

  // Sélectionner la date de visite
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _derniereVisite ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _derniereVisite) {
      setState(() {
        _derniereVisite = picked;
      });
    }
  }

  // Sauvegarder le patient
  Future<void> _savePatient() async {
    // Valider le formulaire
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez corriger les erreurs'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Créer l'objet Patient
      final patient = Patient(
        id: widget.patient?.id, // Garder l'ID si modification
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        pays: _selectedPays!,
        maladie: _selectedMaladie!,
        conseils: _conseilsController.text.trim().isEmpty
            ? null
            : _conseilsController.text.trim(),
        derniereVisite: _derniereVisite,
      );

      final sync = SyncServiceHybrid.instance;

      if (widget.patient == null) {
        await sync.insertPatient(patient);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Patient ${patient.nomComplet} ajouté avec succès',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Modification
        await sync.updatePatient(patient);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Patient ${patient.nomComplet} modifié avec succès',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Retourner à la page précédente
      if (mounted) {
        Navigator.pop(context, true); // true = données modifiées
      }
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.patient != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le Patient' : 'Ajouter un Patient'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: () => _confirmDelete(),
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête avec icône
                    Container(
                      padding: const EdgeInsets.all(AppSizes.paddingL),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: AppColors.textOnPrimary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppSizes.paddingM),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Modifiez les informations du patient'
                                  : 'Remplissez les informations du nouveau patient',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingXL),

                    // Section: Informations personnelles
                    Text(
                      'Informations Personnelles',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingM),

                    // Champ Nom
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom ',
                        hintText: 'Ex: Uwimana',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => _validateName(value, 'Le nom'),
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Champ Prénom
                    TextFormField(
                      controller: _prenomController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom ',
                        hintText: 'Ex: Marie',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => _validateName(value, 'Le prénom'),
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Champ Âge
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Âge ',
                        hintText: 'Ex: 45',
                        prefixIcon: Icon(Icons.cake_rounded),
                        suffixText: 'ans',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: _validateAge,
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Dropdown Pays
                    DropdownButtonFormField<String>(
                      value: _selectedPays,
                      decoration: const InputDecoration(
                        labelText: 'Pays ',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      hint: const Text('Sélectionnez un pays'),
                      items: _paysList.map((pays) {
                        return DropdownMenuItem(value: pays, child: Text(pays));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPays = value;
                        });
                      },
                      validator: _validatePays,
                    ),

                    const SizedBox(height: AppSizes.paddingXL),

                    // Section: Informations médicales
                    Text(
                      'Informations Médicales',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingM),

                    // Dropdown Maladie
                    DropdownButtonFormField<String>(
                      value: _selectedMaladie,
                      decoration: const InputDecoration(
                        labelText: 'Maladie/Diagnostic ',
                        prefixIcon: Icon(Icons.medical_information_rounded),
                      ),
                      hint: const Text('Sélectionnez une maladie'),
                      items: _maladiesList.map((maladie) {
                        return DropdownMenuItem(
                          value: maladie,
                          child: Text(maladie),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMaladie = value;
                        });
                      },
                      validator: _validateMaladie,
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Sélecteur de date
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Première Consultation',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _derniereVisite == null
                              ? 'Sélectionnez une date'
                              : '${_derniereVisite!.day}/${_derniereVisite!.month}/${_derniereVisite!.year}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Champ Conseils (multilignes)
                    TextFormField(
                      controller: _conseilsController,
                      decoration: const InputDecoration(
                        labelText: 'Conseils et Recommandations',
                        hintText: 'Ex: Manger équilibré, repos, traitement...',
                        prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: AppSizes.paddingXL),

                    // Note sur les champs obligatoires
                    // Row(
                    //   children: [
                    //     const Icon(
                    //       Icons.info_outline_rounded,
                    //       size: 16,
                    //       color: AppColors.textSecondary,
                    //     ),
                    //     const SizedBox(width: AppSizes.paddingS),
                    //     Text(
                    //       ' Champs obligatoires',
                    //       style: Theme.of(context).textTheme.bodySmall
                    //           ?.copyWith(color: AppColors.textSecondary),
                    //     ),
                    //   ],
                    // ),

                    // const SizedBox(height: AppSizes.paddingL),

                    // Bouton Enregistrer
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _savePatient,
                      icon: Icon(
                        isEditing ? Icons.save_rounded : Icons.add_rounded,
                      ),
                      label: Text(
                        isEditing
                            ? 'Enregistrer les modifications'
                            : 'Ajouter le patient',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // Bouton Annuler
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingXL),
                  ],
                ),
              ),
            ),
    );
  }

  // Confirmer la suppression
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le patient ${widget.patient!.nomComplet} ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deletePatient();
    }
  }

  // Supprimer le patient
  Future<void> _deletePatient() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = DatabaseService.instance;
      await dbService.deletePatient(widget.patient!.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Patient ${widget.patient!.nomComplet} supprimé'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
