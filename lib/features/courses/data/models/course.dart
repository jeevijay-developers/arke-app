import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String title;
  final String educator;
  final String subject;
  final String thumbnailUrl;
  final double rating;
  final double price;
  final String? description;
  final String? level;
  final String? badge;
  final int? totalEnrolled;
  final int? totalLessons;
  final int? durationHours;
  final List<String> whatYoullLearn;
  final List<String> requirements;

  const Course({
    required this.id,
    required this.title,
    required this.educator,
    required this.subject,
    required this.thumbnailUrl,
    required this.rating,
    required this.price,
    this.description,
    this.level,
    this.badge,
    this.totalEnrolled,
    this.totalLessons,
    this.durationHours,
    this.whatYoullLearn = const [],
    this.requirements = const [],
  });

  bool get isFree => price == 0;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    title: json['name'] as String? ?? '',
    educator: json['educator_name'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    rating: _toDouble(json['rating']),
    price: _toDouble(json['price']),
    description: json['description'] as String?,
    level: json['level'] as String?,
    badge: json['badge'] as String?,
    totalEnrolled: json['total_enrolled'] as int?,
    totalLessons: json['total_lessons'] as int?,
    durationHours: json['duration_hours'] as int?,
    whatYoullLearn: (json['what_youll_learn'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        const [],
    requirements: (json['requirements'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        const [],
  );

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [id, title, educator, subject, thumbnailUrl, rating, price];
}
