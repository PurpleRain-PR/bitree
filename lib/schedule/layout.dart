import 'model.dart';

typedef CourseBlock = ({
  List<Course> courses,
  int startSection,
  int endSection,
});

/// Courses linked by overlapping sections share one timetable entry.
List<CourseBlock> groupOverlappingCourses(List<Course> courses) {
  final sorted = [...courses]
    ..sort((first, second) {
      final section = first.startSection!.compareTo(second.startSection!);
      return section != 0 ? section : first.name.compareTo(second.name);
    });
  final result = <CourseBlock>[];
  var group = <Course>[];
  var groupEnd = 0;

  void finish() {
    result.add((
      courses: List.unmodifiable(group),
      startSection: group.first.startSection!,
      endSection: groupEnd,
    ));
    group = [];
    groupEnd = 0;
  }

  for (final course in sorted) {
    if (group.isNotEmpty && course.startSection! > groupEnd) finish();
    group.add(course);
    if (course.endSection! > groupEnd) groupEnd = course.endSection!;
  }
  if (group.isNotEmpty) finish();

  return result;
}
