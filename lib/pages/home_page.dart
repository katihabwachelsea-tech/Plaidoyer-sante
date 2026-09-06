import 'package:flutter/material.dart';
// import '../utils/constants.dart' as constants;
import '../widgets/metric_card.dart';
import '../models/patient.dart';
import '../services/db_service.dart';
import '../services/sync_service_hybrid.dart';
import '../pages/patient_detail.dart';
import '../models/country_stats.dart';
import '../services/who_api_service.dart';
import 'package:async/async.dart'; // 💡 1. Import pour le Debouncer
import 'package:debounce_throttle/debounce_throttle.dart' as dt;
import '../utils/debouncer.dart';
import '../pages/PatientsListPage.dart';
import '../pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Variables pour les données dynamiques
  List<Patient> _patients = [];
  int _patientCount = 0;
  bool _isLoading = true;
  List<CountryStats> _whoStats = [];
  bool _isOnline = true;
  DateTime? _lastSyncDate;
  int _pendingSyncCount = 0;
  final _sync = SyncServiceHybrid.instance;
  bool _isLoadingStats =
      true; // Initialisé à true car WHOApiService est asynchrone

  final Debouncer _debouncer = Debouncer(delay: Duration(milliseconds: 500));
  // 👈 Ajoutez une valeur initiale vide);
  // 💡 NOUVEAU : Contrôleur pour le champ de recherche
  final TextEditingController _searchController = TextEditingController(
    text: '',
  );

  // Map des drapeaux pour chaque pays
  // final Map<String, String> _countryFlags = {
  //   'Burundi': '🇧🇮',
  //   'Rwanda': '🇷🇼',
  //   'Kenya': '🇰🇪',
  //   'Tanzania': '🇹🇿',
  //   'Uganda': '🇺🇬',
  //   'Ethiopia': '🇪🇹',
  //   'Somalia': '🇸🇴',
  //   'South Sudan': '🇸🇸',
  //   'DR Congo': '🇨🇩',
  //   'Mozambique': '🇲🇿',
  // };

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Méthode centralisée simplifiée
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _isLoadingStats = true;
    });

    try {
      // 1. Vérifier connexion
      _isOnline = await _sync.isOnline();

      // 2. Sync hybride MySQL → SQLite (si en ligne)
      if (_isOnline) {
        final result = await _sync.syncAll();
        if (result.success) {
          _lastSyncDate = _sync.lastSyncAt;
        }
        _pendingSyncCount = await _sync.getPendingCount();
      }

      // 3. Charger patients (cache SQLite)
      await _loadPatients();

      // 4. Charger stats WHO (avec fallback intégré dans WHOApiService)
      await _loadWhoStats();

      // 5. Debug
      await DatabaseService.instance.debugPrintAllData();
    } catch (e) {
      print('❌ Erreur initialisation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _sync.getRecentPatients(5);
      final count = await _sync.getPatientCount();

      print('📊 $count patients (SQLite${_isOnline ? ' + sync MySQL' : ' offline'})');

      setState(() {
        _patients = patients;
        _patientCount = count;
        _lastSyncDate = patients.isNotEmpty
            ? patients.first.dateCreation
            : null;
      });
    } catch (e) {
      print('❌ Erreur chargement patients: $e');
    }
  }

  Future<void> _loadWhoStats() async {
    // 1. Indiquer que le chargement commence
    setState(() {
      _isLoadingStats = true;
    });
    try {
      print('🔄 Chargement statistiques WHO...');

      // Appel direct à WHOApiService qui gère déjà le fallback
      final stats = await WHOApiService.instance.getCancerStatsByCountry();

      print('✅ ${stats.length} pays chargés');
      // 2. Mettre à jour les données ET indiquer que le chargement est fini
      setState(() {
        _whoStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('❌ Erreur stats WHO: $e');
      // 3. Indiquer que le chargement est fini, même en cas d'erreur
      setState(() {
        _whoStats = []; // La liste est vide en cas d'erreur
        _isLoadingStats = false;
      });
    }
  }

  // 💡 NOUVELLE FONCTION : Gestion de la recherche avec Debouncer
  void _onSearchChanged(String query) {
    // Annule la recherche précédente et planifie la nouvelle
    _debouncer.run(() async {
      if (query.isEmpty) {
        // Si la recherche est vide, on recharge la liste complète
        await _loadPatients();
        return;
      }

      setState(() {
        _isLoading = true; // Afficher l'indicateur de chargement
      });

      // Appel de la recherche après le délai de 500ms
      final results = await _sync.searchPatients(query);

      if (mounted) {
        setState(() {
          _patients = results; // Met à jour la liste des patients affichée
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); //  NOUVEAU : Nettoyage du contrôleur
    _debouncer.dispose(); //  NOUVEAU : Nettoyage du Debouncer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppConstants.appSlogan,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textOnPrimary.withOpacity(0.9),
              ),
            ),
            if (!_isOnline && _lastSyncDate != null)
              Text(
                'Données du ${_lastSyncDate!.toLocal().toString().split(' ')[0]} (hors-ligne)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFEAF4F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _initializeData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bannière de bienvenue
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Bienvenue ! Suivi personnalisé pour vos patients",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isOnline ? Colors.green : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isOnline ? Icons.cloud_done : Icons.cloud_off,
                              color: _isOnline ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isOnline
                                    ? 'Connecté — sync MySQL${_pendingSyncCount > 0 ? ' ($_pendingSyncCount en attente)' : ''}'
                                    : 'Hors-ligne — cache SQLite${_pendingSyncCount > 0 ? ' ($_pendingSyncCount à envoyer)' : ''}',
                                style: TextStyle(
                                  color: _isOnline
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText:
                              'Rechercher un patient (Nom, Prénom ou Maladie)...',
                          hintText: 'Ex: John Doe, Cancer du sein',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged(
                                '',
                              ); // Réaffiche la liste complète
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withOpacity(0.5),
                        ),
                        onChanged:
                            _onSearchChanged, // <-- Le lien vers la fonction debouncée
                      ),

                      const SizedBox(
                        height: 20,
                      ), // Espace après le champ de recherche
                      // Section Aperçu
                      Text(
                        'Aperçu Général',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.paddingM),

                      // Grille des métriques
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSizes.paddingS,
                        mainAxisSpacing: AppSizes.paddingS,
                        childAspectRatio: 0.90,
                        children: [
                          MetricCard(
                            title: 'Total Patients ',
                            value: '$_patientCount',
                            subtitle: 'Total enregistrés',
                            color: AppColors.tealCard,
                            icon: Icons.people_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$_patientCount patients enregistrés',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          // MetricCard(
                          //   title: 'Consultations',
                          //   value: '$_patientCount',
                          //   subtitle: 'Total enregistrés',
                          //   color: AppColors.purpleCard,
                          //   icon: Icons.medical_services_rounded,
                          //   onTap: () {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text(
                          //           'Consultations - En développement!',
                          //         ),
                          //         duration: Duration(seconds: 2),
                          //       ),
                          //     );
                          //   },
                          // ),
                          // MetricCard(
                          //   title: 'Suivi Mental',
                          //   value: '$_patientCount',
                          //   subtitle: 'Total enregistrés',
                          //   color: AppColors.greenCard,
                          //   icon: Icons.psychology_rounded,
                          //   onTap: () {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text(
                          //           'Suivi mental - Bientôt disponible!',
                          //         ),
                          //         duration: Duration(seconds: 2),
                          //       ),
                          //     );
                          //   },
                          // ),
                          // MetricCard(
                          //   title: 'Urgences',
                          //   value: '$_patientCount',
                          //   subtitle: 'Total enregistrés',
                          //   color: AppColors.orangeCard,
                          //   icon: Icons.emergency_rounded,
                          //   onTap: () {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text('Urgences - En développement!'),
                          //         duration: Duration(seconds: 2),
                          //       ),
                          //     );
                          //   },
                          // ),
                          MetricCard(
                            title: 'Nouveaux aujourd\'hui',
                            // Remplacer par une valeur stable pour la démo
                            value: '2',
                            subtitle: 'Ajoutés récemment',
                            color: AppColors.purpleCard,
                            icon: Icons.person_add_alt_1_rounded,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cette métrique est une simulation pour la démo.',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    // Petite correction de l'espacement pour les 2 cartes
                      const SizedBox(height: AppSizes.paddingL),

                      // Section Patients récents
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Patients Récents',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () async {
                              //  Assurez-vous de rafraîchir la Home Page si un patient est supprimé ou modifié
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PatientsListPage(),
                                ),
                              );
                              _initializeData(); // Recharge les données de la Home Page
                            },
                            child: const Text('Voir tout'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.paddingM),

                      // Liste des patients
                      _patients.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text(
                                  'Aucun patient trouvé. Ajoutez-en un !',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _patients.length > 5
                                  ? 5
                                  : _patients.length,
                              itemBuilder: (context, index) {
                                final patient = _patients[index];
                                return PatientCard(
                                  name: patient.nomComplet,
                                  condition: patient.maladie,
                                  lastVisit: patient.derniereVisite != null
                                      ? 'Il y a ${DateTime.now().difference(patient.derniereVisite!).inDays} jour(s)'
                                      : 'Première visite',
                                  status: patient.statut,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PatientDetailPage(patient: patient),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                      const SizedBox(height: AppSizes.paddingXL),

                      // Section Statistiques par pays
                      // Text(
                      //   'Statistiques par Pays',
                      //   style: Theme.of(context).textTheme.headlineSmall
                      //       ?.copyWith(fontWeight: FontWeight.bold),
                      // ),
                      // const SizedBox(height: AppSizes.paddingM),

                      // // Affichage stats WHO
                      // // 1. ÉTAT DE CHARGEMENT
                      // if (_isLoadingStats)
                      //   const Center(
                      //     child: Padding(
                      //       padding: EdgeInsets.all(32.0),
                      //       child: CircularProgressIndicator(),
                      //     ),
                      //   )
                      // else if (_whoStats.isEmpty)
                      //   Center(
                      //     child: Padding(
                      //       padding: const EdgeInsets.all(20.0),
                      //       child: Column(
                      //         children: [
                      //           Icon(
                      //             Icons.signal_wifi_off_rounded,
                      //             size: 48,
                      //             color: Colors.grey[400],
                      //           ),
                      //           const SizedBox(height: 10),
                      //           Text(
                      //             'Aucune statistique disponible',
                      //             style: TextStyle(
                      //               color: Colors.grey[600],
                      //               fontSize: 14,
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   )
                      // else
                      //   // Utilisez un Column pour lister vos Cards, comme vous le faisiez
                      //   Column(
                      //     children: _whoStats.map((stat) {
                      //       final flag =
                      //           _countryFlags[stat.countryName] ?? '🌍';
                      //       return Card(
                      //         elevation: 2,
                      //         margin: const EdgeInsets.only(bottom: 12),
                      //         shape: RoundedRectangleBorder(
                      //           borderRadius: BorderRadius.circular(16),
                      //         ),
                      //         child: Padding(
                      //           padding: const EdgeInsets.all(
                      //             AppSizes.paddingL,
                      //           ),
                      //           child: Column(
                      //             children: [
                      //               Row(
                      //                 mainAxisAlignment:
                      //                     MainAxisAlignment.spaceBetween,
                      //                 children: [
                      //                   Row(
                      //                     children: [
                      //                       Container(
                      //                         width: 50,
                      //                         height: 50,
                      //                         decoration: BoxDecoration(
                      //                           color: AppColors.primary
                      //                               .withOpacity(0.1),
                      //                           borderRadius:
                      //                               BorderRadius.circular(12),
                      //                         ),
                      //                         child: Center(
                      //                           child: Text(
                      //                             flag,
                      //                             style: const TextStyle(
                      //                               fontSize: 28,
                      //                             ),
                      //                           ),
                      //                         ),
                      //                       ),
                      //                       const SizedBox(width: 12),
                      //                       Column(
                      //                         crossAxisAlignment:
                      //                             CrossAxisAlignment.start,
                      //                         children: [
                      //                           Text(
                      //                             stat.countryName,
                      //                             style: const TextStyle(
                      //                               fontSize: 16,
                      //                               fontWeight: FontWeight.w600,
                      //                             ),
                      //                           ),
                      //                           Text(
                      //                             'Année: ${stat.year}',
                      //                             style: TextStyle(
                      //                               fontSize: 12,
                      //                               color: Colors.grey[600],
                      //                             ),
                      //                           ),
                      //                         ],
                      //                       ),
                      //                     ],
                      //                   ),
                      //                   Container(
                      //                     padding: const EdgeInsets.symmetric(
                      //                       horizontal: 12,
                      //                       vertical: 6,
                      //                     ),
                      //                     decoration: BoxDecoration(
                      //                       color: AppColors.primary
                      //                           .withOpacity(0.1),
                      //                       borderRadius: BorderRadius.circular(
                      //                         20,
                      //                       ),
                      //                     ),
                      //                     child: Text(
                      //                       '${stat.value.toStringAsFixed(1)}',
                      //                       style: TextStyle(
                      //                         color: AppColors.primary,
                      //                         fontWeight: FontWeight.w600,
                      //                         fontSize: 14,
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 ],
                      //               ),
                      //               const SizedBox(height: 12),
                      //               ClipRRect(
                      //                 borderRadius: BorderRadius.circular(10),
                      //                 child: LinearProgressIndicator(
                      //                   value: (stat.value / 300).clamp(
                      //                     0.0,
                      //                     1.0,
                      //                   ),
                      //                   backgroundColor:
                      //                       AppColors.surfaceVariant,
                      //                   valueColor:
                      //                       AlwaysStoppedAnimation<Color>(
                      //                         AppColors.primary,
                      //                       ),
                      //                   minHeight: 8,
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //       );
                      //     }).toList(),
                      //   ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class PatientCard extends StatelessWidget {
  final String name;
  final String condition;
  final String lastVisit;
  final String status;
  final VoidCallback onTap;

  const PatientCard({
    Key? key,
    required this.name,
    required this.condition,
    required this.lastVisit,
    required this.status,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        onTap: onTap,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition: $condition'),
            Text('Dernière visite: $lastVisit'),
          ],
        ),
        trailing: Text(
          status,
          style: TextStyle(
            color:
                status ==
                    'A revoir' // Le plus ancien/critique
                ? Colors.red
                : status == 'Stable'
                ? Colors
                      .orange // A surveiller (7-30 jours)
                : Colors.green, // Nouveau/Récent (0-7 jours)
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
