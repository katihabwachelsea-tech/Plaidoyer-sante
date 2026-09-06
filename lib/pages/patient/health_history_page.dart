import 'package:flutter/material.dart';

class HealthHistoryPage extends StatefulWidget {
  final int initialTab;

  const HealthHistoryPage({super.key, this.initialTab = 0});

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Historique santé'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Analyses'),
            Tab(text: 'Urgences'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryList(
            title: 'Analyses',
            accent: const Color(0xFF14B8A6),
            items: [
              _HistoryItem(
                label: 'Analyse de sang',
                date: '12 août 2026',
                status: 'Normal',
                note: 'Globules rouges dans la zone attendue.',
                value: '92% / conforme',
              ),
              _HistoryItem(
                label: 'Glycémie',
                date: '08 août 2026',
                status: 'À surveiller',
                note: 'Légère élévation, à suivre avec le médecin.',
                value: '1.2 g/L',
              ),
              _HistoryItem(
                label: 'Électrolytes',
                date: '02 août 2026',
                status: 'Normal',
                note: 'Hydratation et équilibre ionique corrects.',
                value: 'Stable',
              ),
              _HistoryItem(
                label: 'Bilan cardiaque',
                date: '25 juillet 2026',
                status: 'Normal',
                note: 'Aucun signe de trouble particulier.',
                value: 'Bonne stabilité',
              ),
            ],
          ),
          _HistoryList(
            title: 'Urgences',
            accent: const Color(0xFFEF4444),
            items: [
              _HistoryItem(
                label: 'Douleur abdominale',
                date: 'Aujourd’hui • 09:15',
                status: 'À surveiller',
                note: 'Symptôme signalé et suivi rapproché conseillé.',
                value: 'Moyen',
              ),
              _HistoryItem(
                label: 'Fatigue intense',
                date: 'Hier • 18:40',
                status: 'Moyen',
                note: 'Un repos plus important est recommandé.',
                value: 'Signalé',
              ),
              _HistoryItem(
                label: 'Suivi de vigilance',
                date: 'Il y a 3 jours',
                status: 'OK',
                note: 'Évolution stable après la consultation.',
                value: 'Contrôlé',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_HistoryItem> items;

  const _HistoryList({
    required this.title,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _HistoryCard(item: item, accent: accent)),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final Color accent;

  const _HistoryCard({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
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
                  color: accent.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem {
  final String label;
  final String date;
  final String status;
  final String note;
  final String value;

  const _HistoryItem({
    required this.label,
    required this.date,
    required this.status,
    required this.note,
    required this.value,
  });
}
