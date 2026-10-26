import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../schedule/model.dart';
import 'course_detail.dart';
import 'theme.dart';

class CourseTile extends StatelessWidget {
  const CourseTile({
    super.key,
    required this.course,
    required this.controller,
    required this.isToday,
  });

  final Course course;
  final AppController controller;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = courseColors(context, course.colorIndex);
    final fill = isToday
        ? Color.lerp(colors.fill, colors.accent, 0.24)!
        : colors.fill;

    return Semantics(
      button: true,
      label:
          '${course.name}，${course.timeLabel}，${course.room}${isToday ? '，今天' : ''}，查看详情',
      child: ExcludeSemantics(
        child: Tooltip(
          message: '${course.name}\n${course.room}\n${course.teacher}',
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: isToday
                  ? BorderSide(color: colors.accent, width: 1.5)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showCourse(context, controller, course),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 100;
                  final fontSize = narrow ? 12.0 : 14.0;
                  final scaler = MediaQuery.textScalerOf(context);
                  final titleHeight = scaler.scale(fontSize) * 1.25;
                  final roomLineHeight = scaler.scale(fontSize - 1) * 1.25;
                  final available = constraints.maxHeight - 8;
                  final roomLines = course.room.isEmpty
                      ? 0
                      : ((available - titleHeight * 3 - 4) / roomLineHeight)
                            .floor()
                            .clamp(0, narrow ? 4 : 2);
                  final roomStyle = TextStyle(
                    fontSize: fontSize - 1,
                    height: 1.25,
                    color: colors.text,
                  );
                  var roomHeight = 0.0;
                  if (roomLines > 0) {
                    final painter =
                        TextPainter(
                          text: TextSpan(
                            text: course.room,
                            style: DefaultTextStyle.of(context).style
                                .merge(roomStyle),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: scaler,
                          maxLines: roomLines,
                        )..layout(
                          maxWidth: constraints.maxWidth - (narrow ? 6 : 20),
                        );
                    roomHeight = painter.height + 4;
                    painter.dispose();
                  }
                  final titleLines = ((available - roomHeight) / titleHeight)
                      .floor()
                      .clamp(1, 5);
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 3 : 10,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          course.name,
                          textAlign: TextAlign.center,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: 1.25,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        if (roomLines > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            course.room,
                            textAlign: TextAlign.center,
                            maxLines: roomLines,
                            overflow: TextOverflow.ellipsis,
                            style: roomStyle,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
