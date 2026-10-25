import 'dart:convert';
import 'dart:math' as math;

/// Calendar dates are UTC midnights so DST never changes academic week numbers.
DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime campusNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime mondayOf(DateTime date) =>
    calendarDate(date).subtract(Duration(days: date.weekday - 1));

String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

// Week -1 directly precedes week 1; there is no week 0.
int weekOffset(int week) => week > 0 ? week - 1 : week;

int weekFromOffset(int offset) => offset >= 0 ? offset + 1 : offset;

List<int> academicWeeks(int first, int last) => [
  for (var offset = weekOffset(first); offset <= weekOffset(last); offset++)
    weekFromOffset(offset),
];

const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

const sectionTimes = [
  ('08:00', '08:45'),
  ('08:50', '09:35'),
  ('09:55', '10:40'),
  ('10:45', '11:30'),
  ('11:35', '12:20'),
  ('13:20', '14:05'),
  ('14:10', '14:55'),
  ('15:15', '16:00'),
  ('16:05', '16:50'),
  ('16:55', '17:40'),
  ('18:30', '19:15'),
  ('19:20', '20:05'),
  ('20:10', '20:55'),
];

class Course {
  Course({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required List<int> weeks,
    this.teacher = '',
    this.room = '',
    this.campus = '',
    this.number = '',
    this.description = '',
    this.local = false,
  }) : weeks = List.unmodifiable(weeks.toSet().toList()..sort()) {
    if (name.trim().isEmpty || id.isEmpty) {
      throw const FormatException('课程名称或编号缺失');
    }

    if (weekday != null && (weekday! < 1 || weekday! > 7)) {
      throw const FormatException('课程星期超出范围');
    }

    if ((startSection == null) != (endSection == null) ||
        (startSection != null &&
            (startSection! < 1 ||
                endSection! < startSection! ||
                endSection! > sectionTimes.length))) {
      throw const FormatException('课程节次超出作息表范围');
    }

    if (weeks.contains(0)) {
      throw const FormatException('没有第 0 周，请选择负数周或正数周');
    }
  }

  final String id;
  final String name;
  final String teacher;
  final String room;
  final String campus;
  final String number;
  final String description;
  final int? weekday;
  final int? startSection;
  final int? endSection;
  final List<int> weeks;
  // Includes manual additions and local edits of imported courses.
  final bool local;

  String get stableId => local
      ? id
      : _schoolCourseId(
          number: number,
          name: name,
          teacher: teacher,
          campus: campus,
          room: room,
          weekday: weekday,
          startSection: startSection,
          endSection: endSection,
          weeks: weeks,
        );

  bool get isScheduled =>
      weekday != null && startSection != null && weeks.isNotEmpty;

  String get sectionLabel {
    if (startSection == null) return '节次待定';
    if (startSection == endSection) return '第 $startSection 节';

    return '第 $startSection–$endSection 节';
  }

  String get timeLabel => startSection == null
      ? '时间待定'
      : '${sectionTimes[startSection! - 1].$1}–${sectionTimes[endSection! - 1].$2}';

  int get colorIndex => name.runes.fold(0, (value, rune) => value + rune) % 6;

  bool occurs(int week) => isScheduled && weeks.contains(week);

  factory Course._fromSchool(
    Map<String, dynamic> row, {
    required int firstWeekOffset,
  }) {
    int? optionalInt(String key) {
      final value = row[key]?.toString();
      if (value == null || value.isEmpty || value == '0') {
        return null;
      }

      return int.parse(value);
    }

    final mask = row['SKZC']?.toString() ?? '';
    if (!RegExp(r'^[01]*$').hasMatch(mask)) {
      throw const FormatException('学校返回的上课周次格式不正确');
    }

    final name = row['KCM']?.toString() ?? '';
    final teacher = row['SKJS']?.toString() ?? '';
    final room = row['JASMC']?.toString() ?? '';
    final campus = row['XXXQMC']?.toString() ?? '';
    final number = row['KCH']?.toString() ?? '';
    final weekday = optionalInt('SKXQ');
    final startSection = optionalInt('KSJC');
    final endSection = optionalInt('JSJC');
    final description = row['YPSJDD']?.toString() ?? '';
    final weeks = [
      for (var i = 0; i < mask.length; i++)
        if (mask[i] == '1') weekFromOffset(firstWeekOffset + i),
    ];

    return Course(
      id: _schoolCourseId(
        number: number,
        name: name,
        teacher: teacher,
        campus: campus,
        room: room,
        weekday: weekday,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
      ),
      name: name,
      teacher: teacher,
      room: room,
      campus: campus,
      number: number,
      description: description,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      weeks: weeks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'room': room,
    'campus': campus,
    'number': number,
    'description': description,
    'weekday': weekday,
    'startSection': startSection,
    'endSection': endSection,
    'weeks': weeks,
    'local': local,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    name: json['name'] as String,
    teacher: json['teacher'] as String,
    room: json['room'] as String,
    campus: json['campus'] as String,
    number: json['number'] as String,
    description: json['description'] as String,
    weekday: json['weekday'] as int?,
    startSection: json['startSection'] as int?,
    endSection: json['endSection'] as int?,
    weeks: (json['weeks'] as List).cast<int>(),
    local: json['local'] as bool,
  );
}

int _schoolWeekOrigin(List<Map<String, dynamic>> rows) {
  // A term's masks share one origin, which may start before week 1.
  // Infer it from a row whose set bits match all of its displayed weeks.
  for (final row in rows) {
    final described = _describedWeeks(row['YPSJDD']?.toString() ?? '');
    final mask = row['SKZC']?.toString() ?? '';
    final positions = [
      for (var i = 0; i < mask.length; i++)
        if (mask[i] == '1') i,
    ];
    if (described.isEmpty || described.length != positions.length) continue;

    final offset = weekOffset(described.first) - positions.first;
    if (positions.indexed.every(
      (entry) => weekFromOffset(offset + entry.$2) == described[entry.$1],
    )) {
      return offset;
    }
  }

  return 0;
}

List<int> _describedWeeks(String description) {
  final ranges = RegExp(r'(-?\d+)\s*(?:[-–~～]\s*(-?\d+)\s*)?周');
  final weeks = <int>[
    for (final match in ranges.allMatches(description))
      if (match[2] == null)
        int.parse(match[1]!)
      else
        ...academicWeeks(int.parse(match[1]!), int.parse(match[2]!)),
  ];

  return weeks.toSet().toList()..sort();
}

String _schoolCourseId({
  required String number,
  required String name,
  required String teacher,
  required String campus,
  required String room,
  required int? weekday,
  required int? startSection,
  required int? endSection,
  required List<int> weeks,
}) =>
    'school-${jsonEncode([number, name, teacher, campus, room, weekday, startSection, endSection, weeks])}';

String weeksLabel(List<int> weeks) {
  if (weeks.isEmpty) return '周次待定';

  final ranges = <String>[];
  var start = weeks.first;
  var end = start;

  for (final week in weeks.skip(1)) {
    if (week == end + 1) {
      end = week;
    } else {
      ranges.add(start == end ? '$start' : '$start–$end');
      start = end = week;
    }
  }

  ranges.add(start == end ? '$start' : '$start–$end');

  return '${ranges.join('、')} 周';
}

class SemesterSchedule {
  SemesterSchedule({
    required this.term,
    required DateTime firstMonday,
    required List<Course> courses,
    this.syncedAt,
  }) : firstMonday = calendarDate(firstMonday),
       courses = List.unmodifiable(courses) {
    if (term.trim().isEmpty || firstMonday.weekday != DateTime.monday) {
      throw const FormatException('学期或开学日期不正确；开学日期应为第一周周一');
    }
  }

  factory SemesterSchedule.fromSchool({
    required String term,
    required DateTime termStartMonday,
    required List<Map<String, dynamic>> rows,
  }) {
    final firstWeekOffset = _schoolWeekOrigin(rows);

    // The school calendar and course masks both start at the first short-term week.
    // Store the Monday of week 1 so all date calculations share the same baseline.
    return SemesterSchedule(
      term: term,
      firstMonday: calendarDate(termStartMonday)
          .subtract(Duration(days: firstWeekOffset * 7)),
      courses: [
        for (final row in rows)
          Course._fromSchool(row, firstWeekOffset: firstWeekOffset),
      ],
      syncedAt: DateTime.now().toUtc(),
    );
  }

  final String term;

  /// Monday of week 1, after any negative weeks.
  final DateTime firstMonday;
  final List<Course> courses;
  final DateTime? syncedAt;

  int get firstWeek => courses.fold(
    1,
    (first, course) =>
        course.weeks.isEmpty ? first : math.min(first, course.weeks.first),
  );

  int get lastWeek => courses.fold(
    20,
    (count, course) =>
        course.weeks.isEmpty ? count : math.max(count, course.weeks.last),
  );

  List<int> get weeks => academicWeeks(firstWeek, lastWeek);

  String get termLabel {
    final parts = term.split('-');
    if (parts.length != 3 || !['1', '2'].contains(parts[2])) return term;

    return '${parts[0]}–${parts[1]} ${parts[2] == '1' ? '秋季' : '春季'}学期';
  }

  int weekAt(DateTime date) => weekFromOffset(
    (calendarDate(date).difference(firstMonday).inDays / 7).floor(),
  );

  DateTime mondayAt(int week) =>
      firstMonday.add(Duration(days: weekOffset(week) * 7));

  List<Course> coursesAt(int week, {int? weekday}) {
    final scheduled = courses
        .where(
          (course) =>
              course.occurs(week) &&
              (weekday == null || course.weekday == weekday),
        )
        .toList();

    scheduled.sort((first, second) {
      final day = first.weekday!.compareTo(second.weekday!);
      if (day != 0) return day;

      final section = first.startSection!.compareTo(second.startSection!);
      return section != 0 ? section : first.name.compareTo(second.name);
    });

    return scheduled;
  }

  SemesterSchedule copyWith({List<Course>? courses}) => SemesterSchedule(
    term: term,
    firstMonday: firstMonday,
    courses: courses ?? this.courses,
    syncedAt: syncedAt,
  );

  Map<String, dynamic> toJson() => {
    'term': term,
    'firstMonday': dateText(firstMonday),
    'courses': courses.map((course) => course.toJson()).toList(),
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory SemesterSchedule.fromJson(Map<String, dynamic> json) =>
      SemesterSchedule(
        term: json['term'] as String,
        firstMonday: DateTime.parse(json['firstMonday'] as String),
        courses: (json['courses'] as List)
            .map(
              (row) => Course.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList(),
        syncedAt: json['syncedAt'] == null
            ? null
            : DateTime.parse(json['syncedAt'] as String),
      );
}
