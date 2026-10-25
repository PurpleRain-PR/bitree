import 'dart:convert';

import '../schedule/model.dart';
import 'school_network.dart';
import 'school_session.dart';

typedef SchoolJsonRequest = Future<Map<String, dynamic>> Function(
  String path, {
  Map<String, String>? form,
});

/// BIT teaching-center protocol, following BIT101 Android / BIT-Login.
class SchoolService {
  SchoolService(this.session);
  final SchoolSession session;

  Future<String> _currentTerm(SchoolJsonRequest request) async {
    final current = await request('modules/jshkcb/dqxnxq.do');
    final row = _rows(current, 'dqxnxq').firstOrNull;
    if (row == null) throw const FormatException('学校未返回当前学期');
    return _termCode(row);
  }

  Future<({SemesterSchedule schedule, List<String> terms})> synchronize(
    SchoolNetwork network, {
    String? term,
    SchoolJsonRequest? request,
  }) async {
    if (request == null) await session.initializeApp(network);

    final read =
        request ??
        (String path, {Map<String, String>? form}) =>
            session.json(network, path, form: form);
    final selected = term ?? await _currentTerm(read);
    final termResponse = await read('modules/jshkcb/xnxqcx.do');
    final terms = _rows(termResponse, 'xnxqcx').map(_termCode).toList();

    final calendar = await read(
      'wdkbByController/cxzkbrq.do',
      form: {
        'requestParamStr': jsonEncode({'XNXQDM': selected, 'ZC': '1'}),
      },
    );
    final dates = calendar['data'];
    if (dates is! List) throw const FormatException('学校未返回学期校历');
    final monday = dates
        .whereType<Map>()
        .where((row) => row['XQ']?.toString() == '1')
        .firstOrNull;
    if (monday == null || monday['RQ'] is! String) {
      throw const FormatException('学校未返回第一周周一日期');
    }

    final response = await read(
      'modules/xskcb/cxxszhxqkb.do',
      form: {'XNXQDM': selected},
    );
    final rows = _rows(response, 'cxxszhxqkb');

    return (
      schedule: SemesterSchedule(
        term: selected,
        firstMonday: DateTime.parse(monday['RQ'] as String),
        courses: [
          for (var i = 0; i < rows.length; i++) Course.fromSchool(rows[i], i),
        ],
        syncedAt: DateTime.now().toUtc(),
      ),
      terms: terms,
    );
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> value, String key) {
    final data = value['datas'];
    final section = data is Map ? data[key] : null;
    final rows = section is Map ? section['rows'] : null;
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const FormatException('未能读取本科课表，请确认账号可使用本科教学中心。');
    }

    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  String _termCode(Map<String, dynamic> row) {
    final code = row['DM'];
    if (code is! String || code.isEmpty) {
      throw const FormatException('学校返回的学期编号缺失');
    }

    return code;
  }
}
