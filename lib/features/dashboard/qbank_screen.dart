import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class QBankScreen extends StatefulWidget {
  const QBankScreen({super.key});

  @override
  State<QBankScreen> createState() => _QBankScreenState();
}

class _QBankScreenState extends State<QBankScreen> {
  String _subject = 'Physics';
  final _subjects = const ['Physics', 'Chemistry', 'Mathematics', 'Biology'];

  final _topics = const {
    'Physics': [
      _Topic('Kinematics', 142, 0.62),
      _Topic('Newton\'s Laws', 98, 0.41),
      _Topic('Work, Energy, Power', 76, 0.28),
      _Topic('Rotational Motion', 64, 0.15),
      _Topic('Thermodynamics', 110, 0.05),
    ],
    'Chemistry': [
      _Topic('Atomic Structure', 88, 0.55),
      _Topic('Chemical Bonding', 102, 0.38),
      _Topic('Organic — GOC', 134, 0.20),
      _Topic('Equilibrium', 71, 0.10),
    ],
    'Mathematics': [
      _Topic('Algebra', 156, 0.48),
      _Topic('Calculus', 184, 0.31),
      _Topic('Coordinate Geometry', 92, 0.22),
      _Topic('Probability', 64, 0.12),
    ],
    'Biology': [
      _Topic('Cell Biology', 110, 0.61),
      _Topic('Genetics', 86, 0.33),
      _Topic('Human Physiology', 142, 0.18),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final topics = _topics[_subject] ?? const <_Topic>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Question Bank')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: const [
            Icon(Icons.library_books_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text('12,400+ practice questions across subjects',
                  style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _subjects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _subjects[i];
              final selected = s == _subject;
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => setState(() => _subject = s),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: AppColors.border),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ...topics.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicTile(topic: t),
            )),
      ]),
    );
  }
}

class _Topic {
  final String name;
  final int count;
  final double progress;
  const _Topic(this.name, this.count, this.progress);
}

class _TopicTile extends StatelessWidget {
  final _Topic topic;
  const _TopicTile({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(topic.name,
                style: const TextStyle(
                    color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          Text('${topic.count} Q',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: topic.progress,
          minHeight: 6,
          backgroundColor: AppColors.border,
          color: AppColors.primary,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${(topic.progress * 100).toInt()}% solved',
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Practice mode coming soon')));
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Practice'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ]),
      ]),
    );
  }
}
