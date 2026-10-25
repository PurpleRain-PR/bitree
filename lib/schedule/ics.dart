import 'dart:convert';

import 'model.dart';

String scheduleToIcs(SemesterSchedule schedule) {
  final stamp = _timestamp(DateTime.now());
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BITree//Schedule//ZH-CN',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:${_escapeText('BITree ${schedule.termLabel}')}',
  ];

  for (final course in schedule.courses.where((course) => course.isScheduled)) {
    final location = [
      course.campus,
      course.room,
    ].where((part) => part.isNotEmpty).join(' ');

    for (final week in course.weeks) {
      final date = schedule
          .mondayAt(week)
          .add(Duration(days: course.weekday! - 1));
      final start = _campusTime(
        date,
        sectionTimes[course.startSection! - 1].$1,
      );
      final end = _campusTime(date, sectionTimes[course.endSection! - 1].$2);
      final uid = [
        schedule.term,
        course.id,
        '$week',
      ].map(Uri.encodeComponent).join('/');
      final description = [
        '第 $week 周 ${course.sectionLabel}',
        if (course.teacher.isNotEmpty) '教师：${course.teacher}',
        if (course.number.isNotEmpty) '课程号：${course.number}',
        if (course.description.isNotEmpty) course.description,
      ].join('\n');

      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$uid@dev.so1ve.bitree',
        'DTSTAMP:$stamp',
        'DTSTART:${_timestamp(start)}',
        'DTEND:${_timestamp(end)}',
        'SUMMARY:${_escapeText(course.name)}',
        if (location.isNotEmpty) 'LOCATION:${_escapeText(location)}',
        'DESCRIPTION:${_escapeText(description)}',
        'END:VEVENT',
      ]);
    }
  }

  lines.add('END:VCALENDAR');

  return lines.map(_foldLine).join();
}

DateTime _campusTime(DateTime date, String time) {
  final parts = time.split(':');
  // Course times use Beijing time (UTC+8), regardless of the device time zone.
  return date.add(
    Duration(hours: int.parse(parts[0]) - 8, minutes: int.parse(parts[1])),
  );
}

String _timestamp(DateTime value) {
  final utc = value.toUtc();

  String two(int number) => number.toString().padLeft(2, '0');

  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String _escapeText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

String _foldLine(String line) {
  final result = StringBuffer();
  var length = 0;

  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final size = utf8.encode(character).length;
    if (length + size > 75) {
      result.write('\r\n ');
      length = 1;
    }

    result.write(character);
    length += size;
  }

  result.write('\r\n');
  return result.toString();
}
