import 'model.dart';

/// Overlapping classes share a column rather than covering one another.
List<({Course course, int lane, int lanes})> layoutDayCourses(
  List<Course> courses,
) {
  final sorted = [...courses]
    ..sort((a, b) => a.startSection!.compareTo(b.startSection!));
  final result = <({Course course, int lane, int lanes})>[];
  var group = <Course>[];
  var groupEnd = 0;

  void finish() {
    final laneEnds = <int>[];
    final assigned = <({Course course, int lane})>[];
    for (final course in group) {
      var lane = laneEnds.indexWhere((end) => end < course.startSection!);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(course.endSection!);
      } else {
        laneEnds[lane] = course.endSection!;
      }
      assigned.add((course: course, lane: lane));
    }
    result.addAll(
      assigned.map(
        (item) =>
            (course: item.course, lane: item.lane, lanes: laneEnds.length),
      ),
    );
    group = [];
  }

  for (final course in sorted) {
    if (group.isNotEmpty && course.startSection! > groupEnd) {
      finish();
      groupEnd = 0;
    }
    group.add(course);
    if (course.endSection! > groupEnd) groupEnd = course.endSection!;
  }
  finish();
  return result;
}
