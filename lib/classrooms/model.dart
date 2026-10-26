import '../schedule/model.dart';

class SchoolCampus {
  const SchoolCampus({required this.code, required this.name});

  final String code;
  final String name;
}

class SchoolBuilding {
  const SchoolBuilding({
    required this.code,
    required this.name,
    required this.campusCode,
  });

  final String code;
  final String name;
  final String? campusCode;
}

class ClassroomDirectory {
  const ClassroomDirectory({required this.campuses, required this.buildings});

  final List<SchoolCampus> campuses;
  final List<SchoolBuilding> buildings;
}

class ClassroomOccupancy {
  const ClassroomOccupancy({required this.name, required this.busySections});

  final String name;
  final Set<int> busySections;

  /// The continuous free period containing the entire requested range.
  ({int start, int end})? freePeriod(int start, int end) {
    for (var section = start; section <= end; section++) {
      if (busySections.contains(section)) return null;
    }

    var first = start;
    var last = end;
    while (first > 1 && !busySections.contains(first - 1)) {
      first--;
    }
    while (last < sectionTimes.length && !busySections.contains(last + 1)) {
      last++;
    }
    return (start: first, end: last);
  }
}
