import 'dart:convert';

import '../schedule/model.dart';
import 'school_schedule.dart';
import 'school_session.dart';

class SchoolService {
  Future<({SemesterSchedule schedule, List<String> terms})> synchronize(
    SchoolSession session, {
    String? term,
  }) async {
    await session.request(session.network.app, stopAtLogin: true);
    final current = await session.json('modules/jshkcb/dqxnxq.do');
    final selectedTerm =
        term ?? (_rows(current, 'dqxnxq').first['DM'] as String);
    final termResponse = await session.json('modules/jshkcb/xnxqcx.do');
    final terms = _rows(
      termResponse,
      'xnxqcx',
    ).map((row) => row['DM'] as String).toList();
    final calendar = await session.json(
      'wdkbByController/cxzkbrq.do',
      form: {
        'requestParamStr': jsonEncode({'XNXQDM': selectedTerm, 'ZC': '1'}),
      },
    );
    final monday = (calendar['data'] as List).cast<Map>().firstWhere(
      (row) => row['XQ'].toString() == '1',
    );
    final response = await session.json(
      'modules/xskcb/cxxszhxqkb.do',
      form: {'XNXQDM': selectedTerm},
    );
    return (
      schedule: parseSchoolSchedule(
        term: selectedTerm,
        termStartMonday: DateTime.parse(monday['RQ'] as String),
        rows: _rows(response, 'cxxszhxqkb'),
      ),
      terms: terms,
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String key) =>
      ((response['datas'] as Map)[key]['rows'] as List)
          .cast<Map<String, dynamic>>();
}
