import 'package:flutter/material.dart';

import '../agenda/calendar.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import '../schedule/model.dart';
import 'calendar_list.dart';

class TimetableHeader extends StatelessWidget {
  const TimetableHeader({
    super.key,
    required this.controller,
    required this.monday,
    required this.now,
    required this.days,
    required this.gutterWidth,
    required this.todayBackground,
  });

  final AppController controller;
  final DateTime monday;
  final DateTime now;
  final List<List<CalendarItem>> days;
  final double gutterWidth;
  final Color todayBackground;

  void _showItems(BuildContext context, int day, List<CalendarItem> items) {
    showCalendarItems(
      context,
      controller,
      agendaDateLabel(monday.add(Duration(days: day))),
      items,
      emptyMessage: '没有未完成的日程',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = calendarDate(now);
    final dailyAgenda = [
      for (final items in days)
        items.where((item) => item.entry?.isFinished(now) == false).toList(),
    ];

    return Row(
      children: [
        SizedBox(
          width: gutterWidth,
          child: Center(
            child: Text(
              '${monday.month}月',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        for (final (day, items) in dailyAgenda.indexed)
          Expanded(
            child: InkWell(
              onTap: () => _showItems(context, day, items),
              child: _DateHeading(
                date: monday.add(Duration(days: day)),
                today: today,
                todayBackground: todayBackground,
                agendaCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({
    required this.date,
    required this.today,
    required this.todayBackground,
    required this.agendaCount,
  });

  final DateTime date;
  final DateTime today;
  final Color todayBackground;
  final int agendaCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = date == today;
    return Semantics(
      label:
          '${date.month}月${date.day}日${weekdays[date.weekday - 1]}'
          '${current ? '，今天' : ''}${agendaCount > 0 ? '，$agendaCount项日程' : ''}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: current ? todayBackground : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdays[date.weekday - 1].substring(1),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: current ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                      color: current ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: agendaCount > 0
                      ? BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(5),
                        )
                      : null,
                  child: Text(
                    agendaCount > 0 ? '$agendaCount项' : ' ',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
