import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'add_menu.dart';
import 'calendar_list.dart';
import 'course_detail.dart';
import 'data_errors.dart';
import 'schedule_menu.dart';
import 'school_import_button.dart';
import 'week_pager.dart';
import 'week_selector.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  AppController get controller => widget.controller;
  CalendarFilter _filter = CalendarFilter.all;
  bool _list = false;
  bool _showCompleted = false;
  DateTime _localMonday = mondayOf(campusNow());

  void _moveWeek(int offset) {
    if (controller.schedule == null) {
      setState(
        () => _localMonday = _localMonday.add(Duration(days: offset * 7)),
      );
    } else {
      controller.selectWeek(
        weekFromOffset(weekOffset(controller.week) + offset),
      );
    }
  }

  Future<void> _pickWeek() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _localMonday,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _localMonday = mondayOf(date));
  }

  @override
  Widget build(BuildContext context) {
    final schedule = controller.schedule;
    final monday = schedule?.mondayAt(controller.week) ?? _localMonday;
    final today = calendarDate(campusNow());
    final selectedDate =
        today.isBefore(monday) ||
            !today.isBefore(monday.add(const Duration(days: 7)))
        ? monday.add(const Duration(hours: 9))
        : campusNow();
    final list = schedule == null || _list;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: list ? 760 : 1440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final inset = compact ? 12.0 : 24.0;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 4, inset - 4, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: schedule != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: WeekSelector(
                                            controller: controller,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          weekdays[campusNow().weekday - 1],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    )
                                  : TextButton(
                                      onPressed: _pickWeek,
                                      child: Text(
                                        '${monday.month}月${monday.day}日',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                            ),
                          ),
                          if (!compact) ...[
                            IconButton(
                              tooltip: '上一周',
                              onPressed:
                                  schedule == null ||
                                      controller.week > controller.weeks.first
                                  ? () => _moveWeek(-1)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            IconButton(
                              tooltip: '下一周',
                              onPressed:
                                  schedule == null ||
                                      controller.week < controller.weeks.last
                                  ? () => _moveWeek(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                          AddButton(controller: controller, date: selectedDate),
                          SchoolImportButton(controller: controller),
                          ScheduleMenu(
                            schedule: schedule,
                            enabled: !controller.busy,
                          ),
                        ],
                      ),
                    ),
                    DataErrors(controller: controller),
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final filter in CalendarFilter.values)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(filter.label),
                                        selected: _filter == filter,
                                        showCheckmark: false,
                                        onSelected: (_) =>
                                            setState(() => _filter = filter),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_filter == CalendarFilter.deadlines)
                            MenuAnchor(
                              menuChildren: [
                                MenuItemButton(
                                  leadingIcon: Icon(
                                    _showCompleted
                                        ? Icons.check_box_outlined
                                        : Icons.check_box_outline_blank,
                                  ),
                                  onPressed: () => setState(
                                    () => _showCompleted = !_showCompleted,
                                  ),
                                  child: const Text('显示已完成'),
                                ),
                              ],
                              builder: (context, menu, _) => IconButton(
                                tooltip: '完成状态',
                                onPressed: () =>
                                    menu.isOpen ? menu.close() : menu.open(),
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  size: 20,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                enabled: schedule != null,
                                icon: const Icon(
                                  Icons.calendar_view_week_outlined,
                                  size: 18,
                                ),
                                tooltip: '周视图',
                              ),
                              const ButtonSegment(
                                value: true,
                                icon: Icon(
                                  Icons.view_agenda_outlined,
                                  size: 18,
                                ),
                                tooltip: '列表视图',
                              ),
                            ],
                            selected: {list},
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onSelectionChanged: (values) =>
                                setState(() => _list = values.single),
                          ),
                        ],
                      ),
                    ),
                    if (!controller.ready)
                      const LinearProgressIndicator(minHeight: 3),
                    Expanded(
                      child: list
                          ? WeekAgendaList(
                              controller: controller,
                              monday: monday,
                              filter: _filter,
                              showCompleted:
                                  _filter == CalendarFilter.deadlines &&
                                  _showCompleted,
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 6 : inset,
                              ),
                              child: WeekPager(
                                key: ValueKey((
                                  schedule.term,
                                  schedule.firstMonday,
                                  controller.weeks.first,
                                  controller.weeks.last,
                                )),
                                controller: controller,
                                filter: _filter,
                                showCompleted:
                                    _filter == CalendarFilter.deadlines &&
                                    _showCompleted,
                              ),
                            ),
                    ),
                    if (schedule != null &&
                        (_filter == CalendarFilter.all ||
                            _filter == CalendarFilter.courses) &&
                        schedule.courses.any((course) => !course.isScheduled))
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: inset),
                          child: TextButton(
                            onPressed: _unscheduled,
                            child: const Text('时间待定的课程'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unscheduled() => showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('时间待定的课程'),
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
