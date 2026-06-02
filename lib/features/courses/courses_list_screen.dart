import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/colors.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';

class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});
  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  String _query = '';
  String? _subject;
  String _priceFilter = 'All';

  List<Course> _filtered(List<Course> courses) {
    return courses.where((c) {
      if (_query.isNotEmpty &&
          !c.title.toLowerCase().contains(_query.toLowerCase()))
        return false;
      if (_subject != null && c.subject != _subject) return false;
      if (_priceFilter == 'Free' && !c.isFree) return false;
      if (_priceFilter == 'Paid' && c.isFree) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.value ?? const <Course>[];
    final subjects = courses.map((c) => c.subject).toSet().toList();
    final filtered = _filtered(courses);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search courses',
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(
                  'All',
                  _subject == null && _priceFilter == 'All',
                  () => setState(() {
                    _subject = null;
                    _priceFilter = 'All';
                  }),
                ),
                const SizedBox(width: 8),
                for (final s in subjects) ...[
                  _chip(
                    s,
                    _subject == s,
                    () => setState(() => _subject = _subject == s ? null : s),
                  ),
                  const SizedBox(width: 8),
                ],
                _chip(
                  'Free',
                  _priceFilter == 'Free',
                  () => setState(
                    () =>
                        _priceFilter = _priceFilter == 'Free' ? 'All' : 'Free',
                  ),
                ),
                const SizedBox(width: 8),
                _chip(
                  'Paid',
                  _priceFilter == 'Paid',
                  () => setState(
                    () =>
                        _priceFilter = _priceFilter == 'Paid' ? 'All' : 'Paid',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: coursesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) =>
                  const Center(child: Text('Failed to load courses')),
              data: (_) => filtered.isEmpty
                  ? const Center(child: Text('No courses found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return GestureDetector(
                          onTap: () => context.push('/course/${c.id}'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: c.thumbnailUrl,
                                    width: 120,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c.educator,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.rating.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              c.isFree
                                                  ? 'Free'
                                                  : '₹${c.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.primaryLight,
      showCheckmark: false,
    );
  }
}
