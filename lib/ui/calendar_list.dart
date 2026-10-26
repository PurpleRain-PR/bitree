import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    : showAgendaEntry(context, controller, item.entry!);

class CalendarItemTile extends StatefulWidget {
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
  State<CalendarItemTile> createState() => _CalendarItemTileState();
}

class _CalendarItemTileState extends State<CalendarItemTile> {
  bool _deleteArmed = false;

  void _cancelDelete() {
    if (_deleteArmed) setState(() => _deleteArmed = false);
  }

  Future<bool> _swipe(DismissDirection direction, AgendaEntry entry) async {
    final controller = widget.controller;
    if (direction == DismissDirection.startToEnd) {
      _cancelDelete();
      await toggleAgendaDone(context, controller.agenda, entry);
      return false;
    }
    if (controller.confirmDelete && !_deleteArmed) {
      setState(() => _deleteArmed = true);
      HapticFeedback.selectionClick();
      return false;
    }
    return deleteAgendaEntry(context, controller, entry, confirm: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final item = widget.item;
    final showDate = widget.showDate;
    final entry = item.entry;
    final scheme = Theme.of(context).colorScheme;
    final overdue = entry?.overdue(campusNow()) ?? false;
    final when = [
      if (_deleteArmed)
        '再次左滑删除'
      else ...[
        item.kindLabel,
        if (showDate) agendaDateLabel(item.startsAt),
        item.timeLabel,
        if (item.location.isNotEmpty) item.location,
        if (overdue) '已逾期',
        if (entry?.done == true) '已完成',
      ],
    ].join('  ');
    final course = [
      if (entry?.source != null) entry!.source!.label,
      if (entry?.course.isNotEmpty == true) entry!.course,
    ].join('  ');
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      tileColor: _deleteArmed ? scheme.errorContainer : null,
      leading: entry?.isDeadline == true
          ? Tooltip(
              message: entry!.done ? '标为未完成' : '标记完成',
              child: Checkbox(
                value: entry.done,
                shape: const CircleBorder(),
                onChanged: controller.agenda.busy
                    ? null
                    : (_) {
                        _cancelDelete();
                        toggleAgendaDone(context, controller.agenda, entry);
                      },
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
        style: overdue || _deleteArmed ? TextStyle(color: scheme.error) : null,
      ),
      trailing: _deleteArmed
          ? IconButton(
              tooltip: '取消删除',
              onPressed: _cancelDelete,
              icon: const Icon(Icons.close_rounded, size: 20),
            )
          : entry == null
          ? const Icon(Icons.chevron_right_rounded, size: 20)
          : AgendaMenu(controller: controller, entry: entry),
      onTap: () {
        if (_deleteArmed) {
          _cancelDelete();
        } else {
          openCalendarItem(context, controller, item);
        }
      },
    );
    if (entry == null) return tile;

    final deleteBackground = ColoredBox(
      color: scheme.error,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.confirmDelete && !_deleteArmed ? '再次左滑删除' : '松手删除',
                style: TextStyle(color: scheme.onError),
              ),
              const SizedBox(width: 8),
              Icon(Icons.delete_outline, color: scheme.onError),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey(entry.id),
      direction: controller.agenda.busy
          ? DismissDirection.none
          : entry.isDeadline
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      confirmDismiss: (direction) => _swipe(direction, entry),
      movementDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      resizeDuration: null,
      secondaryBackground: entry.isDeadline ? deleteBackground : null,
      background: !entry.isDeadline
          ? deleteBackground
          : ColoredBox(
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
