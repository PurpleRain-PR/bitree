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
    required this.today,
    required this.days,
    required this.pinned,
    required this.gutterWidth,
    required this.dateHeight,
    required this.todayBackground,
  });

  final AppController controller;
  final DateTime monday;
  final DateTime today;
  final List<List<CalendarItem>> days;
  final List<List<CalendarItem>> pinned;
  final double gutterWidth;
  final double dateHeight;
  final Color todayBackground;

  void _showItems(BuildContext context, int day, List<CalendarItem> items) {
    showCalendarItems(
      context,
      controller,
      agendaDateLabel(monday.add(Duration(days: day))),
      items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: dateHeight,
          child: Row(
            children: [
              SizedBox(
                width: gutterWidth,
                child: Center(
                  child: Text(
                    '${monday.month}月',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: InkWell(
                    onTap: () => _showItems(context, day, days[day]),
                    child: _DateHeading(
                      date: monday.add(Duration(days: day)),
                      today: today,
                      todayBackground: todayBackground,
                      pinnedCount: pinned[day].length,
                    ),
                  ),
                ),
            ],
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
    required this.pinnedCount,
  });

  final DateTime date;
  final DateTime today;
  final Color todayBackground;
  final int pinnedCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = date == today;
    return Semantics(
      label:
          '${date.month}月${date.day}日${weekdays[date.weekday - 1]}'
          '${current ? '，今天' : ''}${pinnedCount > 0 ? '，$pinnedCount项日程' : ''}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: current ? todayBackground : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdays[date.weekday - 1].substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: current ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
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
              SizedBox.square(
                dimension: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pinnedCount > 0
                        ? scheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
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
