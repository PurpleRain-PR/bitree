import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'add_menu.dart';
import 'agenda_list_tile.dart';
import 'app_page.dart';
import 'campus_time_builder.dart';
import 'data_errors.dart';
import 'pull_to_reveal_list.dart';
import 'school_import_button.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    this.active = true,
  });

  final AppController controller;
  final bool active;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  AgendaKind? _kind;
  late final _status = TabController(length: 2, vsync: this)
    ..addListener(_statusChanged);

  void _statusChanged() => setState(() {});

  @override
  void dispose() {
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CampusTimeBuilder(active: widget.active, builder: _build);

  Widget _build(BuildContext context, DateTime now) {
    final controller = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final completed = _status.index == 1;
    final entries = controller.agenda.entries
        .where((entry) => _kind == null || entry.kind == _kind)
        .toList();
    final doneCount = entries.where((entry) => entry.isFinished(now)).length;
    final visible =
        entries.where((entry) => entry.isFinished(now) == completed).toList()
          ..sort((a, b) {
            final time = a.startsAt.compareTo(b.startsAt);
            final order = time == 0 ? a.id.compareTo(b.id) : time;
            return completed ? -order : order;
          });
    final days = <DateTime, List<AgendaEntry>>{};
    final overdueDays = <DateTime, List<AgendaEntry>>{};
    for (final entry in visible) {
      final group = entry.overdue(now) ? overdueDays : days;
      group.putIfAbsent(calendarDate(entry.startsAt), () => []).add(entry);
    }

    List<Widget> dayRows(Map<DateTime, List<AgendaEntry>> groups) => [
      for (final day in groups.entries) ...[
        _AgendaDateHeading(
          key: ValueKey(('day', day.key)),
          date: day.key,
          now: now,
        ),
        for (final entry in day.value)
          AgendaListTile(
            key: ValueKey(entry.id),
            controller: controller,
            entry: entry,
            now: now,
          ),
      ],
    ];

    final overdueCount = overdueDays.values.fold(
      0,
      (count, entries) => count + entries.length,
    );

    return AppPage(
      title: const Text('日程'),
      actions: [
        AddButton(controller: controller, includeCourse: false),
        SchoolImportButton(controller: controller, includeSchedule: false),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataErrors(controller: controller),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in [
                  null,
                  AgendaKind.deadline,
                  AgendaKind.event,
                  AgendaKind.exam,
                ])
                  ChoiceChip(
                    label: Text(kind?.label ?? '全部'),
                    selected: _kind == kind,
                    showCheckmark: false,
                    backgroundColor: scheme.surface,
                    selectedColor: scheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: _kind == kind
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: _kind == kind
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: _kind == kind
                          ? Colors.transparent
                          : scheme.outlineVariant,
                    ),
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _status,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            tabs: [
              Tab(text: '未完成 ${entries.length - doneCount}'),
              Tab(text: '已完成 $doneCount'),
            ],
          ),
          if (!controller.agenda.ready && controller.agenda.busy)
            const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: PullToRevealList(
              key: ValueKey((_kind, completed)),
              hiddenLabel: '逾期日程 $overdueCount',
              hiddenChildren: dayRows(overdueDays),
              children: [
                if (days.isEmpty && controller.agenda.ready)
                  Padding(
                    key: const ValueKey('empty-state'),
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: Center(
                      child: Text(
                        completed
                            ? '还没有已完成的日程'
                            : overdueCount > 0
                            ? '没有即将到来的日程'
                            : '没有未完成的日程',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ...dayRows(days),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaDateHeading extends StatelessWidget {
  const _AgendaDateHeading({super.key, required this.date, required this.now});

  final DateTime date;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = date.difference(calendarDate(now)).inDays;
    final label = switch (days) {
      0 => '今天',
      1 => '明天',
      -1 => '昨天',
      _ => weekdays[date.weekday - 1],
    };
    final year = date.year == now.year ? '' : '${date.year}年';

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                color: days == 0 ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: '  $year${date.month}月${date.day}日',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
