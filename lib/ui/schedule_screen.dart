import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../schedule/model.dart';
import 'course_detail.dart';
import 'course_editor.dart';
import 'schedule_menu.dart';
import 'school_screen.dart';
import 'week_pager.dart';
import 'week_selector.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.controller});

  final AppController controller;

  Future<bool?> _import(BuildContext context) =>
      openSchoolPage(context, controller, action: SchoolAction.importSchedule);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final inset = compact ? 16.0 : 28.0;
                final schedule = controller.schedule;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 4, inset - 6, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: WeekSelector(controller: controller),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    weekdays[campusNow().weekday - 1],
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!compact && schedule != null) ...[
                            IconButton(
                              tooltip: '上一周',
                              onPressed: controller.week > schedule.firstWeek
                                  ? () => controller.selectWeek(
                                      weekFromOffset(
                                        weekOffset(controller.week) - 1,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: '下一周',
                              onPressed: controller.week < schedule.lastWeek
                                  ? () => controller.selectWeek(
                                      weekFromOffset(
                                        weekOffset(controller.week) + 1,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                            const SizedBox(width: 12),
                          ],
                          IconButton(
                            tooltip: '添加课程',
                            onPressed: controller.busy
                                ? null
                                : () => editCourse(context, controller),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          IconButton(
                            tooltip: '导入课表',
                            onPressed: controller.busy || controller.schoolBusy
                                ? null
                                : () => _import(context),
                            icon: controller.schoolBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.input_rounded),
                          ),
                          ScheduleMenu(
                            schedule: schedule,
                            enabled: !controller.busy,
                          ),
                        ],
                      ),
                    ),
                    if (controller.error != null)
                      Container(
                        color: scheme.errorContainer,
                        padding: EdgeInsets.fromLTRB(inset, 4, inset, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                controller.error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                            if (controller.loginExpired)
                              TextButton(
                                onPressed:
                                    controller.busy || controller.schoolBusy
                                    ? null
                                    : () => _import(context),
                                child: const Text('继续导入'),
                              ),
                            IconButton(
                              tooltip: '关闭提示',
                              onPressed: controller.dismissError,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    if (!controller.ready)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (schedule == null)
                      Expanded(
                        child: _EmptySchedule(
                          importing: controller.schoolBusy,
                          onImport: controller.busy || controller.schoolBusy
                              ? null
                              : () => _import(context),
                          onAdd: controller.busy
                              ? null
                              : () => editCourse(context, controller),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : inset,
                          ),
                          child: WeekPager(
                            key: ValueKey((
                              schedule.term,
                              schedule.firstMonday,
                              schedule.firstWeek,
                            )),
                            controller: controller,
                          ),
                        ),
                      ),
                      if (schedule.courses.any((course) => !course.isScheduled))
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: inset),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _unscheduled(context),
                              child: const Text('时间待定'),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unscheduled(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('时间待定'),
      children: [
        for (final course in controller.schedule!.courses.where(
          (course) => !course.isScheduled,
        ))
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              showCourse(context, controller, course);
            },
            child: Text(course.name),
          ),
      ],
    ),
  );
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({
    required this.importing,
    required this.onImport,
    required this.onAdd,
  });

  final bool importing;
  final VoidCallback? onImport;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 40,
                color: scheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                '还没有课表',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onImport,
                  icon: importing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.input_rounded, size: 18),
                  label: const Text('导入课表'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加课程'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
