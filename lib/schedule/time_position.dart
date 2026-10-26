import 'model.dart';

int _minutes(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Position in equal-height sections, docked at the edges outside teaching hours.
/// Breaks have no height, so the position waits at the next section boundary.
double sectionOffsetAt(DateTime now) {
  final minute = now.hour * 60 + now.minute + now.second / 60;
  if (minute <= _minutes(sectionTimes.first.$1)) return 0.0;
  if (minute >= _minutes(sectionTimes.last.$2)) {
    return sectionTimes.length.toDouble();
  }

  for (var index = 0; index < sectionTimes.length; index++) {
    final start = _minutes(sectionTimes[index].$1);
    final end = _minutes(sectionTimes[index].$2);
    if (minute < start) return index.toDouble();
    if (minute <= end) return index + (minute - start) / (end - start);
  }
  return sectionTimes.length.toDouble();
}
