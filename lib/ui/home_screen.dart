import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'add_menu.dart';
import 'calendar_list.dart';
import 'data_errors.dart';
import 'schedule_menu.dart';
import 'school_import_button.dart';
import 'school_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenCalendar,
  });
  final AppController controller;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final now = campusNow();
    final today = calendarDate(now);
    final todayItems = calendarItemsOn(
      today,
      controller.schedule,
      controller.agenda.entries,
    ).where((item) => item.entry?.isDeadline != true).toList();
    final deadlines =
        controller.agenda.entries
            .where((entry) => entry.isDeadline && !entry.done)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final exams =
        controller.agenda.entries
            .where(
              (entry) =>
                  entry.kind == AgendaKind.exam &&
                  calendarDate(entry.startsAt).isAfter(today),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '首页',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      AddButton(controller: controller),
                      SchoolImportButton(controller: controller),
                      ScheduleMenu(
                        schedule: controller.schedule,
                        enabled: !controller.busy,
                      ),
                    ],
                  ),
                ),
                DataErrors(controller: controller),
                if (!controller.ready)
                  const LinearProgressIndicator(minHeight: 3),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                agendaDateLabel(today),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: onOpenCalendar,
                              child: const Text('查看日历'),
                            ),
                          ],
                        ),
                      ),
                      if (todayItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '今天没有安排',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      for (final item in todayItems)
                        CalendarItemTile(controller: controller, item: item),
                      if (controller.schedule == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed:
                                  controller.schoolBusy || controller.busy
                                  ? null
                                  : () => openSchoolPage(
                                      context,
                                      controller,
                                      action: SchoolAction.importSchedule,
                                    ),
                              icon: const Icon(Icons.input_rounded, size: 18),
                              label: const Text('导入课表'),
                            ),
                          ),
                        ),
                      if (deadlines.isNotEmpty) ...[
                        _SectionHeader(
                          title: '待办 DDL',
                          count: deadlines.length,
                          onShowAll: () => showCalendarItems(
                            context,
                            controller,
                            '待办 DDL',
                            deadlines.map(CalendarItem.agenda).toList(),
                            showDates: true,
                          ),
                        ),
                        for (final entry in deadlines.take(4))
                          CalendarItemTile(
                            controller: controller,
                            item: CalendarItem.agenda(entry),
                            showDate: true,
                          ),
                      ],
                      if (exams.isNotEmpty) ...[
                        _SectionHeader(
                          title: '临近考试',
                          count: exams.length,
                          onShowAll: () => showCalendarItems(
                            context,
                            controller,
                            '考试安排',
                            exams.map(CalendarItem.agenda).toList(),
                            showDates: true,
                          ),
                        ),
                        for (final entry in exams.take(3))
                          CalendarItemTile(
                            controller: controller,
                            item: CalendarItem.agenda(entry),
                            showDate: true,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.onShowAll,
  });
  final String title;
  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(onPressed: onShowAll, child: Text('全部 $count')),
      ],
    ),
  );
}
