import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'add_menu.dart';
import 'app_page.dart';
import 'calendar_list.dart';
import 'data_errors.dart';
import 'school_import_button.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  AgendaKind? _kind;
  bool _showCompleted = true;
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final now = campusNow();
    final today = calendarDate(now);
    final overdue = <AgendaEntry>[];
    final days = <DateTime, List<AgendaEntry>>{};
    final entries = controller.agenda.entries.toList()
      ..sort((a, b) {
        final time = a.startsAt.compareTo(b.startsAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });

    for (final entry in entries) {
      if (_kind != null && entry.kind != _kind) continue;
      if (entry.done && !_showCompleted) continue;
      if (entry.isDeadline && entry.dueAt.isBefore(now)) {
        overdue.add(entry);
        continue;
      }
      final past = entry.isDeadline
          ? entry.dueAt.isBefore(now)
          : !entry.endsAt!.isAfter(now);
      if (past && !_showPast && !entry.done) continue;
      final day = calendarDate(entry.startsAt);
      days.putIfAbsent(day, () => []).add(entry);
    }

    Widget heading(String label, {bool highlight = false}) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: highlight
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return AppPage(
      title: const Text('日历'),
      actions: [
        AddButton(controller: controller, includeCourse: false),
        SchoolImportButton(controller: controller, includeSchedule: false),
        MenuAnchor(
          menuChildren: [
            CheckboxMenuButton(
              value: _showCompleted,
              onChanged: (value) => setState(() => _showCompleted = value!),
              child: const Text('显示已完成'),
            ),
            CheckboxMenuButton(
              value: _showPast,
              onChanged: (value) => setState(() => _showPast = value!),
              child: const Text('显示已结束'),
            ),
          ],
          builder: (context, menu, _) => IconButton(
            tooltip: '更多',
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataErrors(controller: controller),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                spacing: 8,
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
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
            ),
          ),
          if (!controller.agenda.ready && controller.agenda.busy)
            const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: overdue.isEmpty && days.isEmpty
                ? const Center(child: Text('没有待办安排'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (overdue.isNotEmpty) ...[
                        heading('已截止的 DDL'),
                        for (final entry in overdue)
                          CalendarItemTile(
                            controller: controller,
                            item: CalendarItem.agenda(entry),
                            showDate: true,
                          ),
                      ],
                      for (final day in days.entries) ...[
                        heading(
                          agendaDateLabel(day.key),
                          highlight: day.key == today,
                        ),
                        for (final entry in day.value)
                          CalendarItemTile(
                            controller: controller,
                            item: CalendarItem.agenda(entry),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
