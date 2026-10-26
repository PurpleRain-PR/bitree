import 'model.dart';

class TimetableSelection {
  const TimetableSelection({
    required this.date,
    required this.startSection,
    required this.endSection,
  });

  final DateTime date;
  final int startSection;
  final int endSection;

  DateTime get startsAt => _at(sectionTimes[startSection - 1].$1);
  DateTime get endsAt => _at(sectionTimes[endSection - 1].$2);

  DateTime _at(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return DateTime.utc(date.year, date.month, date.day, parts[0], parts[1]);
  }
}
