import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../services/api_logger.dart';
import '../../utils/doctor_photo.dart';
import '../../widgets/metric_card.dart';
import '../../config/app_config.dart';
import 'payment_page.dart';

class DoctorBookingPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorBookingPage({super.key, required this.doctor});

  @override
  State<DoctorBookingPage> createState() => _DoctorBookingPageState();
}

class _DoctorBookingPageState extends State<DoctorBookingPage> {
  static const String _baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();
  static const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  // Urgence
  String _urgence = 'Normal';
  static const _urgenceOptions = ['Normal', 'Urgent', 'Tres_urgent'];
  static const _urgenceLabels = {
    'Normal':      'Normal',
    'Urgent':      'Urgent',
    'Tres_urgent': 'Très urgent',
  };
  static const _urgenceColors = {
    'Normal':      AppColors.success,
    'Urgent':      AppColors.warning,
    'Tres_urgent': AppColors.error,
  };
  static const _urgenceIcons = {
    'Normal':      Icons.check_circle_outline_rounded,
    'Urgent':      Icons.warning_amber_rounded,
    'Tres_urgent': Icons.emergency_rounded,
  };

  // Pièces jointes
  final List<File> _attachments = [];
  final _picker = ImagePicker();

  late final List<DateTime> _days;
  DateTime? _selectedDate;
  bool _isLoadingSlots = false;
  List<Map<String, dynamic>> _slots = [];
  String? _selectedTime;

  List<Map<String, dynamic>> _services = [];
  bool _isLoadingServices = false;
  int? _selectedServiceId;
  String? _selectedServiceName;
  num? _selectedPrice;

  String? _selectedServiceMode;

  bool _isSubmitting = false;

  int get _doctorId {
    final raw = widget.doctor['user_id'] ?? widget.doctor['id'];
    if (raw is int) return raw;
    return int.parse('$raw');
  }

  String get _doctorName {
    final raw = (widget.doctor['user']?['nom'] ?? widget.doctor['nom'] ?? 'Médecin').toString();
    if (raw.toLowerCase().startsWith('dr')) return raw;
    return 'Dr. $raw';
  }

  String get _specialty => (widget.doctor['specialite'] ?? 'Médecin').toString();
  String get _hopital => (widget.doctor['hopital'] ?? 'Établissement non renseigné').toString();

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = List.generate(14, (i) {
      final d = today.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
    _selectedDate = _days.first;
    _loadServices();
    _loadSlots(_selectedDate!);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() => _storage.read(key: 'jwt_token');

  // ── Pièces jointes ──────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    if (_attachments.length >= 5) {
      _showError('Maximum 5 pièces jointes');
      return;
    }
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() => _attachments.add(File(picked.path)));
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatFbu(num? value) {
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

  String _dayLabel(DateTime date) => _weekdays[date.weekday - 1];

  String _longDate(DateTime date) {
    return '${_dayLabel(date)} ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    final url = '$_baseUrl/patient/doctors/$_doctorId/services';
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      ApiLogger.request(method: 'GET', url: url, headers: headers);
      // Services liés à CE médecin (pas tout le catalogue)
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) {
          setState(() => _services = list);
          if (list.length == 1) _selectService(list.first);
        }
      }
    } catch (e, st) {
      ApiLogger.error(url: url, error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _selectDay(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _slots = [];
      _selectedTime = null;
      _isLoadingSlots = true;
    });
    await _loadSlots(date);
  }

  Future<void> _loadSlots(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final url = '$_baseUrl/patient/doctors/$_doctorId/slots/$dateStr';
    try {
      final token = await _getToken();
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      ApiLogger.request(method: 'GET', url: url, headers: headers);
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) setState(() => _slots = list);
      } else if (mounted) {
        _showError('Impossible de charger les créneaux');
      }
    } catch (e, st) {
      ApiLogger.error(url: url, error: e, stackTrace: st);
      if (mounted) _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  void _selectService(Map<String, dynamic> service) {
    final id = service['id'] is int ? service['id'] as int : int.parse('${service['id']}');
    final prix = service['prix'];
    final mode = (service['mode'] ?? 'presentiel').toString();
    setState(() {
      _selectedServiceId = id;
      _selectedServiceName = service['nom_service'] as String?;
      _selectedPrice = prix == null ? null : num.tryParse('$prix');
      _selectedServiceMode = mode;
    });
  }

  String _modeLabel(String? mode) {
    if (mode == 'teleconsultation') return 'Téléconsultation';
    return 'Présentiel';
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      _showError('Choisissez une date et un créneau');
      return;
    }
    if (_selectedServiceId == null) {
      _showError('Choisissez un type de consultation pour voir le prix');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirmer la demande',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              _summaryLine('Médecin', _doctorName),
              _summaryLine('Date', '${_longDate(_selectedDate!)} · $_selectedTime'),
              _summaryLine('Motif', _reasonController.text.trim()),
              _summaryLine('Consultation', _selectedServiceName ?? 'Consultation'),
              _summaryLine('Mode', _modeLabel(_selectedServiceMode)),
              _summaryLine('Urgence', _urgenceLabels[_urgence] ?? _urgence),
              if (_attachments.isNotEmpty)
                _summaryLine('Pièces jointes', '${_attachments.length} fichier(s) joint(s)'),
              const Divider(height: 28),
              Row(
                children: [
                  const Text(
                    'À payer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    formatFbu(_selectedPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Le rendez-vous reste en attente jusqu’au paiement.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Envoyer la demande'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    await _sendRequest();
  }

  Future<void> _sendRequest() async {
    setState(() => _isSubmitting = true);

    try {
      final token = await _getToken();
      if (token == null) {
        _showError('Session expirée, veuillez vous reconnecter');
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final dateRdv = '$dateStr ${_selectedTime!}:00';

      http.Response response;

      if (_attachments.isEmpty) {
        // ── Pas de fichiers : JSON simple (compatible même sans migration urgence) ──
        final url    = '$_baseUrl/patient/appointments';
        final body   = {
          'medecin_id': _doctorId,
          'service_id': _selectedServiceId,
          'date_rdv':   dateRdv,
          'motif':      _reasonController.text.trim(),
          'urgence':    _urgence,
        };
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        ApiLogger.request(method: 'POST', url: url, headers: headers, body: body);
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
        ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      } else {
        // ── Avec fichiers : multipart ──────────────────────────────────────────
        final url = '$_baseUrl/patient/appointments';
        ApiLogger.request(
          method: 'POST',
          url: url,
          body: {'medecin_id': _doctorId, 'pieces_jointes': '${_attachments.length} fichier(s)'},
        );
        final request = http.MultipartRequest(
          'POST',
          Uri.parse(url),
        );
        request.headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });
        request.fields['medecin_id'] = '$_doctorId';
        request.fields['service_id'] = '$_selectedServiceId';
        request.fields['date_rdv']   = dateRdv;
        request.fields['motif']      = _reasonController.text.trim();
        request.fields['urgence']    = _urgence;

        for (int i = 0; i < _attachments.length; i++) {
          request.files.add(await http.MultipartFile.fromPath(
            'pieces_jointes[$i]',
            _attachments[i].path,
          ));
        }

        final streamed = await request.send()
            .timeout(const Duration(seconds: 60));
        response = await http.Response.fromStream(streamed);
        ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      }
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == true) {
        if (!mounted) return;
        final created = data['data'];
        if (created is Map) {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PaymentPage(
                appointment: Map<String, dynamic>.from(created),
              ),
            ),
          );
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError(data['message'] ?? 'Erreur lors de la réservation');
      }
    } catch (e, st) {
      ApiLogger.error(url: '$_baseUrl/patient/appointments', error: e, stackTrace: st);
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

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Prendre rendez-vous'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  _buildDoctorCard(),
                  const SizedBox(height: 20),
                  _section('Date'),
                  const SizedBox(height: 10),
                  _buildDayStrip(),
                  const SizedBox(height: 18),
                  _section('Créneau'),
                  const SizedBox(height: 10),
                  _buildSlotPicker(),
                  const SizedBox(height: 18),
                  _section('Consultation et tarif'),
                  const SizedBox(height: 10),
                  _buildServicePicker(),
                  const SizedBox(height: 18),
                  _section('Motif'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Précisez le motif de la consultation'
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'Ex. Douleurs persistantes, suivi de contrôle…',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Niveau d'urgence ──────────────────────────────
                  _section('Niveau d\'urgence'),
                  const SizedBox(height: 10),
                  _buildUrgencePicker(),
                  const SizedBox(height: 18),

                  // ── Pièces jointes ────────────────────────────────
                  _section('Pièces jointes (optionnel)'),
                  const SizedBox(height: 4),
                  Text(
                    'Ajoutez jusqu\'à 5 photos ou documents médicaux',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  _buildAttachmentPicker(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
    );
  }

  // ── Urgence picker ───────────────────────────────────────────────────
  Widget _buildUrgencePicker() {
    return Row(
      children: _urgenceOptions.map((opt) {
        final selected = _urgence == opt;
        final color   = _urgenceColors[opt]!;
        final icon    = _urgenceIcons[opt]!;
        final label   = _urgenceLabels[opt]!;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _urgence = opt),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? color : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: selected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Pièces jointes ───────────────────────────────────────────────────
  Widget _buildAttachmentPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Miniatures des fichiers ajoutés
        ..._attachments.asMap().entries.map((entry) {
          final i    = entry.key;
          final file = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  file,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _attachments.removeAt(i)),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),

        // Bouton ajouter (visible si < 5 fichiers)
        if (_attachments.length < 5)
          InkWell(
            onTap: _showAttachmentOptions,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.primary, size: 24),
                  SizedBox(height: 4),
                  Text('Ajouter',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDoctorCard() {
    final photoUrl = doctorPhotoUrl(widget.doctor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          DoctorPhotoImage(
            url: photoUrl,
            width: 56,
            height: 64,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _doctorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  _specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _hopital,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStrip() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = _days[index];
          final selected = _selectedDate != null &&
              _selectedDate!.year == day.year &&
              _selectedDate!.month == day.month &&
              _selectedDate!.day == day.day;
          return InkWell(
            onTap: () => _selectDay(day),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabel(day),
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotPicker() {
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final available = _slots.where((s) => s['available'] == true).toList();
    if (_slots.isEmpty || available.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Aucun créneau libre ce jour. Choisissez une autre date.'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: available.map((slot) {
        final time = slot['time'] as String;
        final selected = _selectedTime == time;
        return ChoiceChip(
          label: Text(time),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.success,
          backgroundColor: AppColors.success.withValues(alpha: 0.10),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.success,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color: selected ? AppColors.success : AppColors.success.withValues(alpha: 0.35),
          ),
          onSelected: (_) => setState(() => _selectedTime = time),
        );
      }).toList(),
    );
  }

  Widget _buildServicePicker() {
    if (_isLoadingServices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(child: Text('Tarifs indisponibles')),
            TextButton(onPressed: _loadServices, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return Column(
      children: _services.map((service) {
        final id = service['id'] is int
            ? service['id'] as int
            : int.parse('${service['id']}');
        final nom = service['nom_service'] as String? ?? 'Consultation';
        final prix = service['prix'] == null ? null : num.tryParse('${service['prix']}');
        final mode = (service['mode'] ?? 'presentiel').toString();
        final isTele = mode == 'teleconsultation';
        final selected = _selectedServiceId == id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _selectService(service),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isTele ? AppColors.info : AppColors.success)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _modeLabel(mode),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isTele ? AppColors.info : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatFbu(prix),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    final ready = _selectedTime != null && _selectedServiceId != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tarif',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text(
                    formatFbu(_selectedPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: (_isSubmitting || !ready) ? null : _submitRequest,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }
}
