import '../schedule/model.dart';
import '../schedule/selection.dart';
import 'model.dart';

class CalendarItem {
  CalendarItem.course(Course value, DateTime date)
    : course = value,
      entry = null,
      title = value.name,
      location = value.room,
      startsAt = TimetableSelection(
        date: date,
        startSection: value.startSection!,
        endSection: value.endSection!,
      ).startsAt,
      endsAt = TimetableSelection(
        date: date,
        startSection: value.startSection!,
        endSection: value.endSection!,
      ).endsAt;

  CalendarItem.agenda(AgendaEntry value)
    : course = null,
      entry = value,
      title = value.title,
      location = value.location,
      startsAt = value.startsAt,
      endsAt = value.endsAt;

  final Course? course;
  final AgendaEntry? entry;
  final String title;
  final String location;
  final DateTime startsAt;
  final DateTime? endsAt;

  String get kindLabel => entry?.kind.label ?? '课程';
  String get timeLabel => entry?.timeLabel ?? course!.timeLabel;
  bool get pinned => entry?.allDay == true || entry?.isDeadline == true;
}

List<CalendarItem> calendarItemsOn(
  DateTime date,
  SemesterSchedule? schedule,
  Iterable<AgendaEntry> entries,
) {
  final items = [
    if (schedule != null)
      for (final course in schedule.coursesAt(
        schedule.weekAt(date),
        weekday: date.weekday,
      ))
        CalendarItem.course(course, date),
    for (final entry in entries)
      if (!entry.done && entry.occursOn(date)) CalendarItem.agenda(entry),
  ];
  items.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return a.startsAt.compareTo(b.startsAt);
  });
  return items;
}

/// Breaks collapse to the boundary between teaching periods.
double timetableOffset(DateTime time, DateTime date) {
  final day = calendarDate(date);
  if (time.isBefore(day)) return 0;
  if (!time.isBefore(day.add(const Duration(days: 1)))) {
    return sectionTimes.length.toDouble();
  }
  final minute = time.hour * 60 + time.minute;
  for (var i = 0; i < sectionTimes.length; i++) {
    int minutes(String clock) {
      final parts = clock.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }

    final start = minutes(sectionTimes[i].$1);
    final end = minutes(sectionTimes[i].$2);
    if (minute <= start) return i.toDouble();
    if (minute < end) return i + (minute - start) / (end - start);
  }
  return sectionTimes.length.toDouble();
}

bool outsideTimetable(CalendarItem item, DateTime date) =>
    !item.pinned &&
    timetableOffset(item.startsAt, date) == timetableOffset(item.endsAt!, date);
