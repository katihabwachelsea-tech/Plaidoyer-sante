import 'package:flutter/material.dart';
import 'health_history_page.dart';

class HealthDetailPage extends StatelessWidget {
  final String section;

  const HealthDetailPage({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final isAnalyses = section == 'analyses';
    final title = isAnalyses ? 'Mes analyses' : 'Urgences';
    final accent = isAnalyses ? const Color(0xFF14B8A6) : const Color(0xFFEF4444);

    final items = isAnalyses
        ? [
            _HealthItem(
              label: 'Analyse de sang',
              date: '12 août 2026',
              status: 'Normal',
              note: 'Globules rouges dans la zone attendue.',
              color: accent,
            ),
            _HealthItem(
              label: 'Glycémie',
              date: '08 août 2026',
              status: 'À surveiller',
              note: 'Valeur légèrement élevée, relancer le suivi.',
              color: const Color(0xFFF59E0B),
            ),
            _HealthItem(
              label: 'Électrolytes',
              date: '02 août 2026',
              status: 'Normal',
              note: 'Hydratation et équilibre ionique corrects.',
              color: accent,
            ),
          ]
        : [
            _HealthItem(
              label: 'Douleur abdominale vivace',
              date: 'Aujourd’hui • 09:15',
              status: 'À surveiller',
              note: 'Risque de gêne intestinale, tenir un suivi rapproché.',
              color: accent,
            ),
            _HealthItem(
              label: 'Fatigue intense',
              date: 'Hier • 18:40',
              status: 'Moyen',
              note: 'Symptôme signalé lors du suivi. Repos recommandé.',
              color: const Color(0xFFF59E0B),
            ),
            _HealthItem(
              label: 'Suivi de vigilance',
              date: 'Il y a 3 jours',
              status: 'OK',
              note: 'Évolution stable après la dernière consultation.',
              color: const Color(0xFF22C55E),
            ),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withAlpha((0.18 * 255).round()), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withAlpha((0.2 * 255).round()), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withAlpha((0.18 * 255).round()),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAnalyses ? Icons.analytics_outlined : Icons.emergency_outlined,
                      color: accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAnalyses ? '3 résultats récents' : '2 éléments signalés',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAnalyses
                              ? 'Dernière mise à jour il y a 2 jours.'
                              : 'Suivi de vigilance recommandé par le médecin.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: isAnalyses ? 'Score santé' : 'Risque',
                    value: isAnalyses ? '92%' : 'Faible',
                    note: isAnalyses ? 'Très bon niveau général' : 'Suivi rapproché conseillé',
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Dernière action',
                    value: isAnalyses ? '3 jours' : '12h',
                    note: isAnalyses ? 'Depuis la dernière analyse' : 'Depuis le dernier signal',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...items.map((item) => _buildItemCard(context, item)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HealthHistoryPage(initialTab: isAnalyses ? 0 : 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: const Text('Historique'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Médecin'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: accent, width: 1.5),
                      foregroundColor: accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, _HealthItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.color.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String note;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.note,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthItem {
  final String label;
  final String date;
  final String status;
  final String note;
  final Color color;

  const _HealthItem({
    required this.label,
    required this.date,
    required this.status,
    required this.note,
    required this.color,
  });
}
