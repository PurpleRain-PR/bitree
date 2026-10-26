import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../agenda/model.dart';

class AgendaStore {
  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/agenda.json');
  }

  Future<List<AgendaEntry>> read() async {
    final file = await _file();
    if (!await file.exists()) return [];

    final rows = jsonDecode(await file.readAsString()) as List;
    return rows
        .map((row) => AgendaEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> write(List<AgendaEntry> entries) async {
    final file = await _file();
    final pending = File('${file.path}.pending');
    await pending.writeAsString(
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      flush: true,
    );
    await pending.rename(file.path);
  }
}
