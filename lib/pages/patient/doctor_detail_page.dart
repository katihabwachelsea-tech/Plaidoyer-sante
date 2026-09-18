import 'package:flutter/material.dart';
import '../../utils/doctor_photo.dart';
import '../../widgets/metric_card.dart';
import 'doctor_booking_page.dart';

class DoctorDetailPage extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const DoctorDetailPage({super.key, required this.doctor});

  String get name => doctor['user']?['nom'] ?? doctor['nom'] ?? 'Dr. Inconnu';
  String get specialite => doctor['specialite'] ?? 'Médecin';
  String get hopital => doctor['hopital'] ?? 'Clinique';
  String get disponibilite => doctor['disponibilite'] ?? 'Horaires non spécifiés';
  String get imageUrl => doctorPhotoUrl(doctor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détails du médecin'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppColors.primary.withAlpha((0.1 * 255).round()),
                ),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.person, size: 52, color: AppColors.primary)
                    : null,
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  specialite,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            _infoTile(Icons.location_on_rounded, 'Hôpital / centre', hopital),
            _infoTile(Icons.access_time_rounded, 'Disponibilité', disponibilite),
            _infoTile(Icons.star_rounded, 'Expérience', 'Plus de 8 ans d’expérience clinique'),
            _infoTile(Icons.medical_services_rounded, 'Consultation', 'Suivi personnalisé et orienté patient'),
            const SizedBox(height: AppSizes.paddingL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorBookingPage(doctor: doctor),
                    ),
                  );

                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demande de rendez-vous envoyée avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded),
                label: const Text('Demander un rendez-vous'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
