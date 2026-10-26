import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'agenda_detail.dart';
import 'agenda_menu.dart';
import 'agenda_operations.dart';
import 'completion_text.dart';
import 'course_detail.dart';
import 'sheet_layout.dart';
import 'swipe_action_tile.dart';

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

  @override
  void didUpdateWidget(covariant CalendarItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.controller.confirmDelete) _deleteArmed = false;
  }

  void _cancelDelete() {
    if (_deleteArmed) setState(() => _deleteArmed = false);
  }

  Future<void> _complete(AgendaEntry entry) {
    _cancelDelete();
    return toggleAgendaDone(
      context,
      widget.controller.agenda,
      entry,
      haptic: false,
    );
  }

  Future<void> _delete(AgendaEntry entry) async {
    final controller = widget.controller;
    if (controller.confirmDelete && !_deleteArmed) {
      setState(() => _deleteArmed = true);
      return;
    }
    await deleteAgendaEntry(context, controller, entry, confirm: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final item = widget.item;
    final showDate = widget.showDate;
    final entry = item.entry;
    final scheme = Theme.of(context).colorScheme;
    final now = campusNow();
    final overdue = entry?.overdue(now) ?? false;
    final when = [
      item.kindLabel,
      if (showDate) agendaDateLabel(item.startsAt),
      item.timeLabel,
      if (item.location.isNotEmpty) item.location,
      if (entry?.isDeadline == true && entry!.dueAt.isBefore(now)) '已截止',
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
      title: CompletionText(
        item.title,
        completed: entry?.done == true,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Stack(
        children: [
          Visibility(
            visible: !_deleteArmed,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: CompletionText(
              [when, if (course.isNotEmpty) course].join('\n'),
              completed: entry?.done == true,
              style: overdue ? TextStyle(color: scheme.error) : null,
            ),
          ),
          if (_deleteArmed)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '再次左滑删除',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
        ],
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

    final needsConfirmation = controller.confirmDelete && !_deleteArmed;
    return SwipeActionTile(
      enabled: !controller.agenda.busy,
      leftAction: TileSwipeAction(
        label: needsConfirmation ? '确认删除' : '删除',
        releaseLabel: needsConfirmation ? '松手确认' : '松手删除',
        icon: Icons.delete_outline,
        background: needsConfirmation ? scheme.errorContainer : scheme.error,
        foreground: needsConfirmation
            ? scheme.onErrorContainer
            : scheme.onError,
        onInvoke: () => _delete(entry),
      ),
      rightAction: entry.isDeadline
          ? TileSwipeAction(
              label: entry.done ? '未完成' : '完成',
              releaseLabel: entry.done ? '松手恢复' : '松手完成',
              icon: entry.done ? Icons.undo_rounded : Icons.check_rounded,
              background: scheme.primaryContainer,
              foreground: scheme.onPrimaryContainer,
              onInvoke: () => _complete(entry),
            )
          : null,
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
                title: CompletionText(
                  item.title,
                  completed: item.entry?.done == true,
                ),
                subtitle: CompletionText(
                  [
                    item.kindLabel,
                    if (item.entry?.source != null) item.entry!.source!.label,
                    if (item.entry?.course.isNotEmpty == true)
                      item.entry!.course,
                    if (showDates) agendaDateLabel(item.startsAt),
                    item.timeLabel,
                    if (item.location.isNotEmpty) item.location,
                  ].join('\n'),
                  completed: item.entry?.done == true,
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
