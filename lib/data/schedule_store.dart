import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../schedule/model.dart';

class ScheduleStore {
  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/schedule.json');
  }

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
    final file = await _file();
    if (!await file.exists()) {
      return {'selectedTerm': null, 'semesters': <String, dynamic>{}};
    }

    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> write(SemesterSchedule schedule) async {
    final library = await _readLibrary();
    final semesters = library['semesters'] as Map<String, dynamic>;
    semesters[schedule.term] = schedule.toJson();
    library['selectedTerm'] = schedule.term;

    final file = await _file();
    final pending = File('${file.path}.pending');
    await pending.writeAsString(jsonEncode(library), flush: true);
    await pending.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
