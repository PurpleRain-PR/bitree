import '../agenda/model.dart';
import 'json_file.dart';

class AgendaStore {
  final _file = const JsonFile('agenda.json');

  Future<List<AgendaEntry>> read() async {
    return await _file.read(
          (json) => (json as List)
              .map((row) => AgendaEntry.fromJson(row as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  Future<void> write(List<AgendaEntry> entries) {
    return _file.write(entries.map((entry) => entry.toJson()).toList());
  }
}
