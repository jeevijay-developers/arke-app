import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String name;
  final String? internalName;
  final String? description;
  final String? thumbnailUrl;
  final String target;       // 'IIT-JEE' | 'NEET' | 'Foundation'
  final String courseClass;  // '8'..'12' | '12th_pass'
  final String language;     // 'Hindi' | 'English'
  final double mrp;
  final double salePrice;
  final double discountPercent;
  final bool showPriceWithGst;
  final bool isCourseFree;
  final int? maxUsageDays;
  final DateTime? courseEndDate;
  final int priority;
  final String? badge;
  final bool isActive;
  final bool isFeatured;
  final List<String> tags;
  final double rating;
  final String? assignedTeacherId;
  final List<String> whatYoullLearn;
  final List<String> requirements;

  // Joined teacher name (from profiles/teachers table if joined)
  final String? teacherName;

  const Course({
    required this.id,
    required this.name,
    this.internalName,
    this.description,
    this.thumbnailUrl,
    required this.target,
    required this.courseClass,
    this.language = 'Hindi',
    this.mrp = 0,
    this.salePrice = 0,
    this.discountPercent = 0,
    this.showPriceWithGst = false,
    this.isCourseFree = false,
    this.maxUsageDays,
    this.courseEndDate,
    this.priority = 0,
    this.badge,
    this.isActive = true,
    this.isFeatured = false,
    this.tags = const [],
    this.rating = 0,
    this.assignedTeacherId,
    this.whatYoullLearn = const [],
    this.requirements = const [],
    this.teacherName,
  });

  double get displayPrice =>
      showPriceWithGst ? salePrice * 1.18 : salePrice;

  bool get hasDiscount => mrp > 0 && salePrice < mrp;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        internalName: j['internal_name'] as String?,
        description: j['description'] as String?,
        thumbnailUrl: j['thumbnail_url'] as String?,
        target: j['target'] as String? ?? 'JEE',
        courseClass: j['class'] as String? ?? '11',
        language: j['language'] as String? ?? 'Hindi',
        mrp: _toDouble(j['mrp']),
        salePrice: _toDouble(j['sale_price']),
        discountPercent: _toDouble(j['discount_percent']),
        showPriceWithGst: j['show_price_with_gst'] as bool? ?? false,
        isCourseFree: j['is_course_free'] as bool? ?? false,
        maxUsageDays: _toInt(j['max_usage_days']),
        courseEndDate: j['course_end_date'] != null
            ? DateTime.tryParse(j['course_end_date'] as String)
            : null,
        priority: _toInt(j['priority']) ?? 0,
        badge: j['badge'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        isFeatured: j['is_featured'] as bool? ?? false,
        tags: _toStringList(j['tags']),
        rating: _toDouble(j['rating']),
        assignedTeacherId: j['assigned_teacher_id'] as String?,
        whatYoullLearn: _toStringList(j['what_youll_learn']),
        requirements: _toStringList(j['requirements']),
        teacherName: j['teacher_name'] as String?,
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static List<String> _toStringList(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

  @override
  List<Object?> get props => [id, name, target, courseClass, salePrice, isFeatured];
}
