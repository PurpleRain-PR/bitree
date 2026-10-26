import 'package:html/parser.dart' as html;

import '../agenda/deadline_source.dart';
import '../agenda/model.dart';
import 'school_errors.dart';
import 'school_session.dart';

Future<List<AgendaEntry>> fetchLexueDeadlines(
  SchoolSession session,
  SchoolResponse page,
) async {
  final source = DeadlineSource.lexue;
  final sesskey = RegExp(r'''["']sesskey["']\s*:\s*["']([^"']+)["']''')
      .firstMatch(page.text)?[1];
  if (sesskey == null) throw const SessionExpired();
  final exported = await session.request(
    source.origin.resolve('/calendar/export.php'),
    form: {
      'sesskey': sesskey,
      '_qf__core_calendar_export_form': '1',
      'events[exportevents]': 'all',
      'period[timeperiod]': 'recentupcoming',
      'generateurl': '获取日历网址',
    },
    stopAtLogin: true,
  );
  final block = html.parse(exported.text).querySelector('.calendarurl');
  final address = block == null
      ? null
      : RegExp(r'https://\S+').firstMatch(block.text)?[0];
  if (address == null) throw const SchoolRequestError('乐学没有返回日历导出地址。');
  final url = Uri.parse(address);
  if (url.host != source.host ||
      url.scheme != 'https' ||
      url.userInfo.isNotEmpty) {
    throw const SchoolRequestError('乐学返回的日历地址无效。');
  }
  final calendar = await session.request(url, stopAtLogin: true);
  return _parseLexueCalendar(calendar.text);
}

List<AgendaEntry> _parseLexueCalendar(String calendar) {
  if (!calendar.contains('BEGIN:VCALENDAR')) {
    throw const SchoolRequestError('乐学没有返回日历，请重新获取。');
  }
  final unfolded = calendar.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final result = <AgendaEntry>[];
  for (final block in unfolded.split('BEGIN:VEVENT').skip(1)) {
    final properties = <String, ({String parameters, String value})>{};
    for (final line
        in block.split('END:VEVENT').first.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon);
      properties[key.split(';').first] = (
        parameters: key,
        value: _unescapeCalendarText(line.substring(colon + 1)),
      );
    }
    final start = properties['DTSTART']!;
    final dateOnly = start.value.length == 8;
    final rawUrl = properties['URL']?.value;
    final taskUrl = rawUrl == null ? null : Uri.parse(rawUrl);
    result.add(
      AgendaEntry(
        id: 'lexue-${properties['UID']!.value}',
        title: properties['SUMMARY']!.value,
        kind: AgendaKind.deadline,
        startsAt: _calendarDate(start.value, start.parameters),
        allDay: dateOnly,
        notes: html
            .parse(properties['DESCRIPTION']?.value ?? '')
            .body!
            .text
            .trim(),
        course: properties['CATEGORIES']?.value ?? '',
        source: DeadlineSource.lexue,
        local: false,
        url:
            taskUrl != null &&
                taskUrl.scheme == 'https' &&
                taskUrl.host == DeadlineSource.lexue.host &&
                taskUrl.userInfo.isEmpty &&
                (taskUrl.path.startsWith('/mod/') ||
                    taskUrl.path.startsWith('/course/'))
            ? taskUrl
            : null,
      ),
    );
  }
  return result;
}

String _unescapeCalendarText(String value) => value.replaceAllMapped(
  RegExp(r'\\([nN,;\\])'),
  (match) => switch (match[1]) {
    'n' || 'N' => '\n',
    _ => match[1]!,
  },
);

DateTime _calendarDate(String value, String parameters) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
  ).firstMatch(value);
  if (match == null) throw FormatException('无法识别乐学日期：$value');
  final date = DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
    int.parse(match[4] ?? '0'),
    int.parse(match[5] ?? '0'),
    int.parse(match[6] ?? '0'),
  );
  final timezone = parameters
      .split(';')
      .where((part) => part.startsWith('TZID='))
      .firstOrNull
      ?.substring(5)
      .replaceAll('"', '');
  if (match[7] == 'Z' || timezone == 'UTC') {
    return date.add(const Duration(hours: 8));
  }
  if (timezone != null && timezone != 'Asia/Shanghai') {
    throw FormatException('乐学日历使用了未支持的时区：$timezone');
  }
  return date;
}
