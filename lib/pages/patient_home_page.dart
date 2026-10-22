import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/patient_api_service.dart';
import '../utils/doctor_photo.dart';
import '../widgets/join_tele_button.dart';
import '../widgets/metric_card.dart';
import 'doctors_list_page.dart';
import 'patient/doctor_booking_page.dart';
import 'patient/payment_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  // Médecins
  List<dynamic> _doctors = [];
  List<dynamic> _allDoctors = []; // copie complète pour le filtre local
  bool _isLoading = false;
  bool _showAllDoctors = false;
  static const int _doctorsPreviewCount = 5;

  // Vrais rendez-vous chargés depuis GET /api/appointments
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDoctors();
    _loadAppointments();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAppointments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  // ── Médecins ────────────────────────────────────────────────────────────

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.instance.fetchDoctors();
      if (result['success'] == true) {
        final list = result['doctors'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _allDoctors = list;
            _doctors = list;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement médecins: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Rendez-vous ─────────────────────────────────────────────────────────

  /// Charge les vrais rendez-vous du patient connecté.
  /// GET /api/appointments → filtre côté Flutter : futurs + En_attente|Confirme
  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final rawList = await PatientApiService.instance.getAppointments();

      if (mounted) {
        final upcoming = rawList.where((appt) {
          final date = _appointmentDate(appt);
          final statut = (appt['statut'] as String?) ?? '';
          return date != null &&
              date.isAfter(DateTime.now()) &&
              (statut == 'En_attente' ||
                  statut == 'Accepte' ||
                  statut == 'Confirme');
        }).toList();
        final paymentDue = rawList.where(_isPaymentDue).toList()
          ..sort(
            (a, b) => _appointmentDate(a)!.compareTo(_appointmentDate(b)!),
          );
        final otherUpcoming = upcoming.where((appt) => !_isPaymentDue(appt));

        setState(() {
          _appointments = [...paymentDue, ...otherUpcoming].take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement RDV: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  // ── Recherche ────────────────────────────────────────────────────────────

  // ── Recherche locale ────────────────────────────────────────────────────

  void _searchDoctors(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _doctors = List.from(_allDoctors));
      return;
    }
    setState(() {
      _doctors = _allDoctors.where((doc) {
        final nom = (doc['user']?['nom'] ?? doc['nom'] ?? '')
            .toString()
            .toLowerCase();
        final spec = (doc['specialite'] ?? '').toString().toLowerCase();
        final hop = (doc['hopital'] ?? '').toString().toLowerCase();
        return nom.contains(q) || spec.contains(q) || hop.contains(q);
      }).toList();
    });
  }

  void _navigateToDoctorsList() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DoctorsListPage()))
        .then((_) {
          _loadDoctors();
          _loadAppointments();
        });
  }

  // ── Build principal ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final firstName = user?.fullName.split(' ').first ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _loadDoctors();
            await _loadAppointments();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'Bonjour, $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Trouvez un médecin et prenez rendez-vous.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _buildSearchBar(),
              if (_searchController.text.trim().isNotEmpty)
                _buildDoctorSuggestions(),
              // ── Bannière paiement si un RDV attend le paiement ──────
              _buildPaymentBanner(),
              const SizedBox(height: 22),
              _sectionTitle('Prochains rendez-vous'),
              const SizedBox(height: 10),
              _buildNextAppointment(),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _sectionTitle('Médecins')),
                  TextButton(
                    onPressed: _navigateToDoctorsList,
                    child: const Text('Voir tous'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDoctorList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return TextFormField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Nom, spécialité ou hôpital',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _searchController.clear();
                  _searchDoctors('');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      onChanged: (value) {
        setState(() {});
        _searchDoctors(value);
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildDoctorSuggestions() {
    return const SizedBox.shrink(); // Suggestions supprimées — filtre local direct
  }

  Future<void> _openPayment(Map<String, dynamic> appt) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentPage(appointment: appt)),
    );
    if (mounted) await _loadAppointments();
  }

  /// Bannière orange si au moins un RDV a été accepté et attend le paiement.
  Widget _buildPaymentBanner() {
    // Chercher les RDV en statut Accepte dans _appointments
    final rdvsAPayer = _appointments
        .where((a) => (a['statut'] as String?) == 'Accepte')
        .toList();

    if (rdvsAPayer.isEmpty) return const SizedBox.shrink();

    final appt = rdvsAPayer.first;
    final medecin = appt['medecin'] as Map<String, dynamic>?;
    final doctorNom = medecin?['user']?['nom']?.toString() ?? 'votre médecin';
    final drName = doctorNom.toLowerCase().startsWith('dr')
        ? doctorNom
        : 'Dr. $doctorNom';
    final nbRdv = rdvsAPayer.length;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: InkWell(
        onTap: () => _openPayment(appt),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payment_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nbRdv == 1
                          ? '$drName a accepté votre demande'
                          : '$nbRdv rendez-vous acceptés',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Touchez pour procéder au paiement',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFFD97706),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _appointmentDate(Map<String, dynamic> appointment) {
    final rawDate = (appointment['date_rdv'] ?? appointment['date_heure'] ?? '')
        .toString();
    if (rawDate.isEmpty) return null;
    try {
      return DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal();
    } on FormatException {
      return null;
    }
  }

  bool _isPaymentDue(Map<String, dynamic> appointment) {
    if (appointment['statut'] != 'Accepte') return false;
    final invoice = appointment['invoice'];
    final date = _appointmentDate(appointment);
    return invoice is Map &&
        invoice['statut_paiement'] != 'Paye' &&
        date != null &&
        date.isAfter(DateTime.now().subtract(const Duration(hours: 2)));
  }

  Future<void> _openDoctor(dynamic doctor) async {
    final map = Map<String, dynamic>.from(doctor as Map);
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DoctorBookingPage(doctor: map)),
    );
    if (booked == true) _loadAppointments();
  }

  String _doctorName(dynamic doctor) {
    final user = doctor['user'];
    final raw = user is Map && user['nom'] != null
        ? user['nom'].toString()
        : (doctor['nom'] ?? 'Médecin').toString();
    if (raw.toLowerCase().startsWith('dr')) return raw;
    return 'Dr. $raw';
  }

  Widget _buildDoctorList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_doctors.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Aucun médecin trouvé.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final visible = _showAllDoctors
        ? _doctors
        : _doctors.take(_doctorsPreviewCount).toList();
    final hasMore = _doctors.length > _doctorsPreviewCount;

    return Column(
      children: [
        ...visible.map((doctor) => _buildDoctorCard(doctor)),
        if (hasMore) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showAllDoctors = !_showAllDoctors),
              icon: Icon(
                _showAllDoctors
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showAllDoctors
                    ? 'Voir moins'
                    : 'Voir plus (${_doctors.length - _doctorsPreviewCount} autres)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoctorCard(dynamic doctor) {
    final name = _doctorName(doctor);
    final specialite = (doctor['specialite'] ?? 'Médecin').toString();
    final hopital = (doctor['hopital'] ?? 'Établissement non renseigné')
        .toString();

    final photoUrl = doctorPhotoUrl(doctor, index: _doctors.indexOf(doctor));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo médecin
          DoctorPhotoImage(
            url: photoUrl,
            width: 60,
            height: 68,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    specialite,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        hopital,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DoctorModePriceChips(doctor: doctor is Map ? doctor : {}),
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => _openDoctor(doctor),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Prendre RDV',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextAppointment() {
    // Chargement en cours
    if (_isLoadingAppointments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Aucun RDV à venir
    if (_appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: AppColors.primary.withAlpha((0.55 * 255).round()),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun rendez-vous à venir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Prenez rendez-vous avec l\'un de nos médecins',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToDoctorsList,
                icon: const Icon(Icons.search),
                label: const Text('Trouver un médecin'),
              ),
            ),
          ],
        ),
      );
    }

    // RDV réels chargés depuis le backend
    final dateFormat = DateFormat('EEE d MMM • HH:mm', 'fr_FR');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec bouton actualiser
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_appointments.length} rendez-vous à venir',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppColors.primary,
                ),
                tooltip: 'Actualiser',
                onPressed: _loadAppointments,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cartes RDV
          ..._appointments.map((appt) {
            // Extraction des champs retournés par AppointmentController.index()
            final medecinObj = appt['medecin'] as Map<String, dynamic>?;
            final medecinUser = medecinObj?['user'] as Map<String, dynamic>?;
            final doctorName =
                medecinUser?['nom'] ?? appt['motif'] ?? 'Médecin';

            final serviceObj = appt['service'] as Map<String, dynamic>?;
            final serviceName =
                serviceObj?['nom_service'] ?? appt['motif'] ?? 'Consultation';

            final statut = (appt['statut'] as String?) ?? '';
            final isConfirme = statut == 'Confirme';
            final isAccepte = statut == 'Accepte';

            // Format date — Laravel retourne date_rdv (datetime)
            final rawDate = (appt['date_rdv'] ?? appt['date_heure'] ?? '')
                .toString();
            String dateLabel = rawDate;
            try {
              final dt = DateTime.parse(
                rawDate.replaceFirst(' ', 'T'),
              ).toLocal();
              dateLabel = dateFormat.format(dt);
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((0.04 * 255).round()),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withAlpha((0.15 * 255).round()),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctorName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              serviceName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              dateLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isConfirme
                              ? AppColors.success.withValues(alpha: 0.12)
                              : isAccepte
                              ? AppColors.info.withValues(alpha: 0.12)
                              : AppColors.warning.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isConfirme
                              ? 'Confirmé'
                              : isAccepte
                              ? 'Accepté — À payer'
                              : 'En attente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConfirme
                                ? AppColors.success
                                : isAccepte
                                ? AppColors.info
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isAccepte) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _openPayment(appt),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Payer maintenant'),
                      ),
                    ),
                  ],
                  if (canJoinTeleFromMap(appt)) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: JoinTeleButton(
                        meetingUrl: appt['meeting_url']?.toString(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToDoctorsList,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau rendez-vous'),
            ),
          ),
        ],
      ),
    );
  }
}
