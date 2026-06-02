import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class EducatorsScreen extends StatefulWidget {
  const EducatorsScreen({super.key});

  @override
  State<EducatorsScreen> createState() => _EducatorsScreenState();
}

class _EducatorsScreenState extends State<EducatorsScreen> {
  final _list = <_Educator>[
    _Educator('Dr. Vikram Thapar', 'Physics', 4.8, '12k followers', false),
    _Educator('Prof. Meera Iyer', 'Biology', 4.7, '9.4k followers', true),
    _Educator('Rajesh Sharma', 'Mathematics', 4.6, '7.1k followers', false),
    _Educator('Dr. Anjali Rao', 'Chemistry', 4.9, '15k followers', true),
    _Educator('Imran Khan', 'Physics', 4.5, '5.2k followers', false),
    _Educator('Nisha Verma', 'Mathematics', 4.7, '8.6k followers', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Educators')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EducatorCard(
          educator: _list[i],
          onToggle: () => setState(() => _list[i] = _list[i].copyToggle()),
        ),
      ),
    );
  }
}

class _Educator {
  final String name, subject, followers;
  final double rating;
  final bool followed;
  _Educator(this.name, this.subject, this.rating, this.followers, this.followed);
  _Educator copyToggle() =>
      _Educator(name, subject, rating, followers, !followed);
}

class _EducatorCard extends StatelessWidget {
  final _Educator educator;
  final VoidCallback onToggle;
  const _EducatorCard({required this.educator, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            educator.name.substring(0, 1),
            style: const TextStyle(
                color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(educator.name,
                style: const TextStyle(
                    color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${educator.subject} • ${educator.followers}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.star, size: 13, color: Colors.amber),
              const SizedBox(width: 2),
              Text(educator.rating.toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        OutlinedButton(
          onPressed: onToggle,
          style: OutlinedButton.styleFrom(
            backgroundColor: educator.followed ? AppColors.primary : Colors.white,
            foregroundColor: educator.followed ? Colors.white : AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(educator.followed ? 'Following' : 'Follow',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
  }
}
