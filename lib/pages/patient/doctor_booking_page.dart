import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../widgets/metric_card.dart';
import '../../config/app_config.dart';

class DoctorBookingPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorBookingPage({super.key, required this.doctor});

  @override
  State<DoctorBookingPage> createState() => _DoctorBookingPageState();
}

class _DoctorBookingPageState extends State<DoctorBookingPage> {
  static const String _baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  // ─── État date & créneaux ───
  DateTime? _selectedDate;
  bool _isLoadingSlots = false;
  List<Map<String, dynamic>> _slots = [];
  String? _selectedTime; // ex: "09:00"

  // ─── Services ───
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingServices = false;
  int? _selectedServiceId;
  String? _selectedServiceName;

  // ─── Soumission ───
  bool _isSubmitting = false;

  // ─── Infos médecin ───
  int get _doctorId => widget.doctor['id'] is int
      ? widget.doctor['id'] as int
      : int.parse('${widget.doctor['id']}');

  String get _doctorName =>
      widget.doctor['user']?['nom'] ?? widget.doctor['nom'] ?? 'Dr. Inconnu';

  String get _specialty => widget.doctor['specialite'] ?? 'Médecin';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── Chargement des services disponibles ──────────────────────────────────

  Future<String?> _getToken() => _storage.read(key: 'jwt_token');

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/services'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) setState(() => _services = list);
      }
    } catch (_) {
      // Services non chargés — on affiche un message dans l'UI
    } finally {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  // ── Sélection de date & chargement des créneaux ──────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr'),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _slots = [];
      _selectedTime = null;
      _isLoadingSlots = true;
    });

    await _loadSlots(picked);
  }

  Future<void> _loadSlots(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/appointments/slots/$_doctorId/$dateStr'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) setState(() => _slots = list);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de charger les créneaux')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  // ── Soumission de la demande ──────────────────────────────────────────────

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showError('Veuillez choisir une date');
      return;
    }
    if (_selectedTime == null) {
      _showError('Veuillez choisir un créneau horaire');
      return;
    }
    if (_selectedServiceId == null) {
      _showError('Veuillez choisir un type de consultation');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _getToken();
      if (token == null) {
        _showError('Session expirée, veuillez vous reconnecter');
        return;
      }

      // Format datetime attendu par Laravel : "Y-m-d H:i:s"
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final dateRdv = '$dateStr ${_selectedTime!}:00';

      final response = await http.post(
        Uri.parse('$_baseUrl/appointments/request'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'medecin_id':  _doctorId,
          'service_id':  _selectedServiceId,
          'date_rdv':    dateRdv,
          'motif':       _reasonController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande envoyée ! Procédez au paiement pour confirmer.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError(data['message'] ?? 'Erreur lors de la réservation');
      }
    } catch (e) {
      _showError('Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Demande de rendez-vous'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            children: [
              // ─ Carte médecin ─────────────────────────────────────────
              _buildDoctorCard(),
              const SizedBox(height: AppSizes.paddingL),

              // ─ Date ──────────────────────────────────────────────────
              _buildSectionTitle('Date souhaitée'),
              const SizedBox(height: AppSizes.paddingS),
              _buildDatePicker(),
              const SizedBox(height: AppSizes.paddingL),

              // ─ Créneaux ───────────────────────────────────────────────
              if (_selectedDate != null) ...[
                _buildSectionTitle('Choisir un créneau'),
                const SizedBox(height: AppSizes.paddingS),
                _buildSlotPicker(),
                const SizedBox(height: AppSizes.paddingL),
              ],

              // ─ Service ────────────────────────────────────────────────
              _buildSectionTitle('Type de consultation'),
              const SizedBox(height: AppSizes.paddingS),
              _buildServicePicker(),
              const SizedBox(height: AppSizes.paddingL),

              // ─ Motif ──────────────────────────────────────────────────
              _buildSectionTitle('Motif de consultation'),
              const SizedBox(height: AppSizes.paddingS),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez préciser le motif'
                    : null,
                decoration: const InputDecoration(
                  hintText: 'Ex: Suivi de routine, douleur persistante...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              // ─ Bouton ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Text(
                          'Valider la demande',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: const Icon(Icons.person, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doctorName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _specialty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withAlpha((0.35 * 255).round())),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Choisir une date'
                    : DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                        .format(_selectedDate!),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (_selectedDate != null)
              const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotPicker() {
    if (_isLoadingSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 10),
            Text('Aucun créneau disponible pour cette date'),
          ],
        ),
      );
    }

    final available = _slots.where((s) => s['available'] == true).toList();

    if (available.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 10),
            Text('Tous les créneaux sont pris ce jour'),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _slots.map((slot) {
        final time = slot['time'] as String;
        final isAvailable = slot['available'] == true;
        final isSelected = _selectedTime == time;

        return GestureDetector(
          onTap: isAvailable ? () => setState(() => _selectedTime = time) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isAvailable
                      ? Colors.white
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isAvailable
                        ? AppColors.primary.withAlpha(80)
                        : Colors.grey.shade300,
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isAvailable
                        ? AppColors.primary
                        : Colors.grey.shade400,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicePicker() {
    if (_isLoadingServices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Services non chargés'),
            ),
            TextButton(
              onPressed: _loadServices,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedServiceId,
      hint: const Text('Choisir un type de consultation'),
      items: _services.map((service) {
        final id = service['id'] is int
            ? service['id'] as int
            : int.parse('${service['id']}');
        final nom = service['nom_service'] as String? ?? 'Service';
        final prix = service['prix'];
        final prixStr = prix != null
            ? ' — ${prix.toString()} BIF'
            : '';
        return DropdownMenuItem<int>(
          value: id,
          child: Text('$nom$prixStr'),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        final service = _services.firstWhere(
          (s) => (s['id'] is int ? s['id'] : int.parse('${s['id']}')) == value,
        );
        setState(() {
          _selectedServiceId = value;
          _selectedServiceName = service['nom_service'] as String?;
        });
      },
      validator: (v) =>
          v == null ? 'Veuillez choisir un type de consultation' : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
