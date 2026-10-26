import 'package:flutter/foundation.dart';

import '../data/agenda_store.dart';
import 'model.dart';

class AgendaController extends ChangeNotifier {
  AgendaController(this._store);

  final AgendaStore _store;
  List<AgendaEntry> _entries = const [];
  bool ready = false;
  bool busy = false;
  String? error;

  List<AgendaEntry> get entries => _entries;

  Future<void> load() async {
    if (busy) return;
    busy = true;
    ready = false;
    error = null;
    notifyListeners();
    try {
      _entries = List.unmodifiable(await _store.read());
      ready = true;
    } catch (failure) {
      error = '读取安排失败：$failure';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> save(AgendaEntry entry) =>
      _write([..._entries.where((item) => item.id != entry.id), entry]);

  Future<bool> delete(AgendaEntry entry) =>
      _write(_entries.where((item) => item.id != entry.id).toList());

  Future<bool> replaceExams(String term, List<AgendaEntry> exams) {
    final edited = {
      for (final entry in _entries)
        if (entry.kind == AgendaKind.exam && entry.term == term && entry.local)
          entry.id,
    };
    return _write([
      ..._entries.where(
        (entry) =>
            entry.kind != AgendaKind.exam || entry.term != term || entry.local,
      ),
      ...exams.where((entry) => !edited.contains(entry.id)),
    ]);
  }

  Future<bool> mergeDeadlines(List<AgendaEntry> incoming) {
    final entries = {for (final entry in _entries) entry.id: entry};
    for (final entry in incoming) {
      final saved = entries[entry.id];
      final next = saved?.local == true ? saved! : entry;
      entries[entry.id] = next.withDone(entry.done || saved?.done == true);
    }
    return _write(entries.values.toList());
  }

  Future<bool> _write(List<AgendaEntry> next) async {
    if (!ready || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _store.write(next);
      _entries = List.unmodifiable(next);
      return true;
    } catch (failure) {
      error = '保存安排失败：$failure';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
