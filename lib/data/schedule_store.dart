import '../schedule/model.dart';
import 'json_file.dart';

class ScheduleStore {
  final _file = const JsonFile('schedule.json');

  Future<SemesterSchedule?> read() async {
    final library = await _readLibrary();
    final selected = library['selectedTerm'];
    if (selected == null) return null;

    final semesters = library['semesters'] as Map<String, dynamic>;
    return SemesterSchedule.fromJson(
      semesters[selected] as Map<String, dynamic>,
    );
  }

  Future<SemesterSchedule?> readTerm(String term) async {
    final library = await _readLibrary();
    final semesters = library['semesters'] as Map<String, dynamic>;
    final value = semesters[term];

    return value == null
        ? null
        : SemesterSchedule.fromJson(value as Map<String, dynamic>);
  }

  Future<List<String>> terms() async {
    final library = await _readLibrary();
    final semesters = library['semesters'] as Map<String, dynamic>;
    return semesters.keys.toList();
  }

  Future<Map<String, dynamic>> _readLibrary() async {
    return await _file.read((json) => json as Map<String, dynamic>) ??
        {'selectedTerm': null, 'semesters': <String, dynamic>{}};
  }

  Future<void> write(SemesterSchedule schedule) async {
    final library = await _readLibrary();
    final semesters = library['semesters'] as Map<String, dynamic>;
    semesters[schedule.term] = schedule.toJson();
    library['selectedTerm'] = schedule.term;

    await _file.write(library);
  }

  Future<void> clear() {
    return _file.delete();
  }
}
