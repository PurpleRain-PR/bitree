import 'package:flutter/material.dart';

import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'add_menu.dart';
import 'app_page.dart';
import 'campus_time_builder.dart';
import 'course_detail.dart';
import 'course_editor.dart';
import 'data_errors.dart';
import 'schedule_menu.dart';
import 'school_import_button.dart';
import 'school_screen.dart';
import 'today_agenda.dart';
import 'week_pager.dart';
import 'week_selector.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, this.active = true});

  final AppController controller;
  final bool active;

  @override
  Widget build(BuildContext context) =>
      CampusTimeBuilder(active: active, builder: _build);

  Widget _build(BuildContext context, DateTime today) {
    final schedule = controller.schedule;
    final currentWeek =
        schedule == null || schedule.weekAt(today) == controller.week;
    final entries = currentWeek
        ? controller.agenda.entries
              .where(
                (entry) => !entry.isFinished(today) && entry.occursOn(today),
              )
              .toList()
        : <AgendaEntry>[];
    entries.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final monday = schedule?.mondayAt(controller.week);
    final selectedDate =
        monday == null || schedule!.weekAt(today) == controller.week
        ? today
        : monday.add(const Duration(hours: 9));

    return AppPage(
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (schedule == null)
            const Text('首页')
          else
            WeekSelector(controller: controller),
          if (currentWeek)
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(fontSize: 13),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(weekdays[today.weekday - 1]),
                  if (entries.isNotEmpty)
                    Text(
                      '${entries.length}项${entries.every((entry) => entry.isDeadline) ? '待办' : '日程'}',
                    ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        AddButton(controller: controller, date: selectedDate),
        SchoolImportButton(controller: controller),
        ScheduleMenu(controller: controller),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DataErrors(controller: controller),
          if (!controller.ready) const LinearProgressIndicator(minHeight: 3),
          if (entries.isNotEmpty)
            TodayAgenda(controller: controller, entries: entries, now: today),
          Expanded(
            child: schedule == null
                ? Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: controller.busy || controller.schoolBusy
                              ? null
                              : () => openSchoolPage(
                                  context,
                                  controller,
                                  action: SchoolAction.importSchedule,
                                ),
                          icon: const Icon(Icons.input_rounded, size: 20),
                          label: const Text('导入课表'),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.busy
                              ? null
                              : () => editCourse(context, controller),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('添加课程'),
                        ),
                      ],
                    ),
                  )
                : WeekPager(
                    key: ValueKey((
                      schedule.term,
                      schedule.firstMonday,
                      controller.weeks.first,
                      controller.weeks.last,
                    )),
                    controller: controller,
                    active: active,
                  ),
          ),
          if (schedule != null &&
              schedule.courses.any((course) => !course.isScheduled))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _unscheduled(context),
                child: const Text('时间待定的课程'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _unscheduled(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('时间待定的课程'),
      children: [
        for (final course in controller.schedule!.courses.where(
          (course) => !course.isScheduled,
        ))
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(dialogContext);
              showCourse(context, controller, course);
            },
            child: Text(course.name),
          ),
      ],
    ),
  );
}
