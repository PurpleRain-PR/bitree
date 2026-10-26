import 'dart:convert';

import '../classrooms/model.dart';
import '../schedule/model.dart';
import 'school_errors.dart';
import 'school_session.dart';

Future<ClassroomDirectory> fetchClassroomDirectory(
  SchoolSession session,
) async {
  await _openClassroomApp(session, 'kxjasbyMobile');

  final campuses = _rows(
    await session.json(
      'modules/jxllb/ggzdpx.do?dicCode=48682&SFSY=1&order=%2BDM',
      app: 'kxjasbyMobile',
    ),
    'ggzdpx',
  );
  final buildings = _rows(
    await session.json('modules/jxllb/cxjxl.do', app: 'kxjasbyMobile'),
    'cxjxl',
  );

  return ClassroomDirectory(
    campuses: [
      for (final row in campuses)
        SchoolCampus(code: _text(row, 'DM'), name: _text(row, 'MC')),
    ],
    buildings: [
      for (final row in buildings)
        SchoolBuilding(
          code: _text(row, 'JXLDM'),
          name: _text(row, 'JXLMC'),
          campusCode: _text(row, 'XXXQDM'),
        ),
    ],
  );
}

Future<List<ClassroomOccupancy>> fetchClassroomOccupancy(
  SchoolSession session, {
  required String buildingCode,
  required DateTime date,
}) async {
  await _openClassroomApp(session, 'kxjas');

  // Use the school's calendar, independently of the user's local timetable.
  final terms = _rows(await _query(session, 'dqxnxqcx'), 'dqxnxqcx');
  if (terms.isEmpty) throw const SchoolRequestError('学校未返回当前学期。');
  final term = terms.first;
  final day = _data(
    await _query(session, 'rqzhzcjc', {
      'RQ': dateText(date),
      'XN': _text(term, 'XNDM'),
      'XQ': _text(term, 'XQDM'),
    }),
    'rqzhzcjc',
  );
  final week = int.tryParse(day['ZC'].toString());
  final weekday = int.tryParse(day['XQJ'].toString());
  if (week == null || weekday == null || weekday < 1 || weekday > 7) {
    throw const SchoolRequestError('学校未返回这一天的校历，请换个日期重试。');
  }

  final form = {
    'XNXQDM': _text(term, 'DM'),
    'ZC': '$week',
    'XQ': '$weekday',
    'RQ': dateText(date),
    'querySetting': jsonEncode([
      {
        'name': 'JXLDM',
        'caption': '教学楼代码',
        'builder': 'equal',
        'linkOpt': 'AND',
        'value': buildingCode,
      },
    ]),
    '*order': '+JASMC',
    'pageSize': '50',
  };
  final rooms = <ClassroomOccupancy>[];
  for (var page = 1; page <= 100; page++) {
    final response = await _query(session, 'cxjsqk', {
      ...form,
      'pageNumber': '$page',
    });
    final rows = _rows(response, 'cxjsqk');
    for (final row in rows) {
      if (!sectionTimes.indexed.any(
        (item) => row.containsKey('JC${item.$1 + 1}'),
      )) {
        throw const SchoolRequestError('学校未返回教室占用情况，请稍后重试。');
      }
      rooms.add(
        ClassroomOccupancy(
          name: _text(row, 'JASMC'),
          busySections: {
            for (var section = 1; section <= sectionTimes.length; section++)
              // Each entry describes a booking; 1_ marks an occupied section.
              if ((row['JC$section']?.toString() ?? '')
                  .split(',')
                  .any((booking) => booking.startsWith('1_')))
                section,
          },
        ),
      );
    }
    final total = int.tryParse(
      _data(response, 'cxjsqk')['totalSize'].toString(),
    );
    if (total != null ? rooms.length >= total : rows.length < 50) return rooms;
    if (rows.isEmpty) break;
  }
  throw const SchoolRequestError('教室列表未能完整加载，请重试。');
}

Future<void> _openClassroomApp(SchoolSession session, String app) async {
  await session.request(session.network.app, stopAtLogin: true);
  await session.request(
    session.network.endpoint(
      'api/getAppConfig/wdkbby-5959167891382285.do',
      app: 'funauthapp',
    ),
    stopAtLogin: true,
  );
  await session.request(
    session.network.timetableTranslations,
    stopAtLogin: true,
  );
  await session.request(
    session.network.endpoint('*default/index.do', app: app),
    stopAtLogin: true,
  );
}

Future<Map<String, dynamic>> _query(
  SchoolSession session,
  String name, [
  Map<String, String> form = const {},
]) => session.json('modules/kxjas/$name.do', app: 'kxjas', form: form);

Map<String, dynamic> _data(Map<String, dynamic> response, String name) {
  final data = response['datas'];
  if (data is Map && data[name] is Map<String, dynamic>) return data[name];

  throw SchoolRequestError(
    (response['msg'] ?? response['message'] ?? '学校未返回查询数据，请稍后重试。').toString(),
  );
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String name) {
  final rows = _data(response, name)['rows'];
  if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
    throw const SchoolRequestError('学校返回的列表不完整，请稍后重试。');
  }
  return rows.cast<Map<String, dynamic>>();
}

String _text(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString();
  if (value == null || value.isEmpty) {
    throw const SchoolRequestError('学校返回的查询数据不完整，请稍后重试。');
  }
  return value;
}
