import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'agenda_editor.dart';
import 'course_detail.dart';
import 'sheet_layout.dart';

IconData agendaIcon(AgendaKind kind) => switch (kind) {
  AgendaKind.event => Icons.event_outlined,
  AgendaKind.deadline => Icons.flag_outlined,
  AgendaKind.exam => Icons.edit_note_rounded,
};

Future<void> openCalendarItem(
  BuildContext context,
  AppController controller,
  CalendarItem item,
) => item.course != null
    ? showCourse(context, controller, item.course!)
    : editAgenda(context, controller.agenda, entry: item.entry!);

class CalendarItemTile extends StatelessWidget {
  const CalendarItemTile({
    super.key,
    required this.controller,
    required this.item,
    this.showDate = false,
  });

  final AppController controller;
  final CalendarItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final scheme = Theme.of(context).colorScheme;
    final overdue = entry?.overdue(campusNow()) ?? false;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(
        entry == null ? Icons.school_outlined : agendaIcon(entry.kind),
        color: overdue ? scheme.error : scheme.onSurfaceVariant,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: entry?.done == true ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        [
          item.kindLabel,
          if (entry?.source != null) entry!.source!.label,
          if (entry?.course.isNotEmpty == true) entry!.course,
          if (showDate) agendaDateLabel(item.startsAt),
          item.timeLabel,
          if (item.location.isNotEmpty) item.location,
          if (overdue) '已逾期',
        ].join('  '),
      ),
      trailing: entry?.isDeadline == true
          ? Checkbox(
              value: entry!.done,
              onChanged: controller.agenda.busy
                  ? null
                  : (value) => controller.agenda.save(entry.withDone(value!)),
            )
          : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => openCalendarItem(context, controller, item),
    );
  }
}

Future<void> showCalendarItems(
  BuildContext context,
  AppController controller,
  String title,
  List<CalendarItem> items, {
  bool showDates = false,
}) async {
  final selected = await showModalBottomSheet<CalendarItem>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
      top: false,
      child: SheetLayout(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              ListTile(
                leading: Icon(
                  item.entry == null
                      ? Icons.school_outlined
                      : agendaIcon(item.entry!.kind),
                ),
                title: Text(item.title),
                subtitle: Text(
                  [
                    item.kindLabel,
                    if (item.entry?.source != null) item.entry!.source!.label,
                    if (item.entry?.course.isNotEmpty == true)
                      item.entry!.course,
                    if (showDates) agendaDateLabel(item.startsAt),
                    item.timeLabel,
                    if (item.location.isNotEmpty) item.location,
                  ].join('\n'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, item),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('这一天没有安排'),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected != null && context.mounted) {
    await openCalendarItem(context, controller, selected);
  }
}
