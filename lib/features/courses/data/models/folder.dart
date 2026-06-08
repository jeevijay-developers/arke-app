class CourseFolder {
  final String id;
  final String courseId;
  final String? parentId;
  final String name;
  final int order;
  final int itemCount; // populated in-app after a count query

  const CourseFolder({
    required this.id,
    required this.courseId,
    this.parentId,
    required this.name,
    this.order = 0,
    this.itemCount = 0,
  });

  bool get isLevel2 => parentId == null;

  factory CourseFolder.fromJson(Map<String, dynamic> j, {int itemCount = 0}) =>
      CourseFolder(
        id: j['id'] as String,
        courseId: j['course_id'] as String,
        parentId: j['parent_id'] as String?,
        name: j['name'] as String? ?? '',
        order: j['order'] as int? ?? 0,
        itemCount: itemCount,
      );
}
