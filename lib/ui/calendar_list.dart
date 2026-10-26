import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'agenda_detail.dart';
import 'agenda_menu.dart';
import 'agenda_operations.dart';
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
    : showAgendaEntry(context, controller.agenda, item.entry!);

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
    final when = [
      item.kindLabel,
      if (showDate) agendaDateLabel(item.startsAt),
      item.timeLabel,
      if (item.location.isNotEmpty) item.location,
      if (overdue) '已逾期',
      if (entry?.done == true) '已完成',
    ].join('  ');
    final course = [
      if (entry?.source != null) entry!.source!.label,
      if (entry?.course.isNotEmpty == true) entry!.course,
    ].join('  ');
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: entry?.isDeadline == true
          ? Tooltip(
              message: entry!.done ? '标为未完成' : '标记完成',
              child: Checkbox(
                value: entry.done,
                shape: const CircleBorder(),
                onChanged: controller.agenda.busy
                    ? null
                    : (_) =>
                          toggleAgendaDone(context, controller.agenda, entry),
              ),
            )
          : Icon(
              entry == null ? Icons.school_outlined : agendaIcon(entry.kind),
            ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: entry?.done == true ? TextDecoration.lineThrough : null,
          color: entry?.done == true ? scheme.onSurfaceVariant : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [when, if (course.isNotEmpty) course].join('\n'),
        style: overdue ? TextStyle(color: scheme.error) : null,
      ),
      trailing: entry == null
          ? const Icon(Icons.chevron_right_rounded, size: 20)
          : AgendaMenu(controller: controller.agenda, entry: entry),
      onTap: () => openCalendarItem(context, controller, item),
    );
    if (entry?.isDeadline != true) return tile;

    return Dismissible(
      key: ValueKey(entry!.id),
      direction: controller.agenda.busy
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await toggleAgendaDone(context, controller.agenda, entry);
        // Completing a task changes its state, not its place in the list.
        return false;
      },
      movementDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      resizeDuration: null,
      background: ColoredBox(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.done ? Icons.undo_rounded : Icons.check_rounded,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  entry.done ? '标为未完成' : '标记完成',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
      child: tile,
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
