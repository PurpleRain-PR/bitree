package dev.so1ve.bitree

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.TextPaint
import android.view.View
import android.widget.RemoteViews
import androidx.core.widget.RemoteViewsCompat

open class TimetableWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context)
    }

    override fun onDisabled(context: Context) {
        updateAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> updateAll(context)
        }
    }

    companion object {
        private const val REFRESH = "dev.so1ve.bitree.widget.REFRESH"
        private val cardBackgrounds = intArrayOf(
            R.drawable.widget_course_green,
            R.drawable.widget_course_copper,
            R.drawable.widget_course_blue,
            R.drawable.widget_course_purple,
            R.drawable.widget_course_yellow,
            R.drawable.widget_course_teal,
        )
        private val cardTextColors = intArrayOf(
            R.color.widget_course_green_text,
            R.color.widget_course_copper_text,
            R.color.widget_course_blue_text,
            R.color.widget_course_purple_text,
            R.color.widget_course_yellow_text,
            R.color.widget_course_teal_text,
        )

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val providers = listOf(
                TimetableWidget::class.java to R.layout.timetable_widget,
                WideTimetableWidget::class.java to R.layout.timetable_widget_wide,
            )
            val widgets = providers.flatMap { (provider, layout) ->
                manager.getAppWidgetIds(ComponentName(context, provider))
                    .map { id -> id to layout }
            }
            val alarm = context.getSystemService(AlarmManager::class.java)
            val refresh = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, TimetableWidget::class.java).setAction(REFRESH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (widgets.isEmpty()) {
                alarm.cancel(refresh)
                return
            }

            val content = readWidgetContent(context)
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            widgets.forEach { (id, layout) ->
                val views = RemoteViews(context.packageName, layout)
                views.setTextViewText(R.id.widget_date, content.heading)
                views.setTextViewText(R.id.widget_empty, content.emptyMessage)
                views.setEmptyView(R.id.widget_courses, R.id.widget_empty)
                views.setOnClickPendingIntent(R.id.widget_header, open)
                views.setOnClickPendingIntent(R.id.widget_empty, open)
                views.setPendingIntentTemplate(R.id.widget_courses, open)

                views.setViewVisibility(
                    R.id.widget_message,
                    if (content.courses.isEmpty()) View.GONE else View.VISIBLE,
                )
                if (content.courses.isNotEmpty()) {
                    views.setTextViewText(
                        R.id.widget_message,
                        context.getString(R.string.widget_course_count, content.courses.size),
                    )
                }

                val resources = context.resources
                val widthDp = manager.getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                val width = if (widthDp > 0) {
                    widthDp * resources.displayMetrics.density
                } else {
                    manager.getAppWidgetInfo(id).minWidth.toFloat()
                }
                val columns = if (layout == R.layout.timetable_widget_wide) 2 else 1
                val textWidth = (
                    width - 2 * resources.getDimension(R.dimen.widget_padding) -
                        (columns - 1) * resources.getDimension(R.dimen.widget_column_spacing)
                    ) / columns - 2 * resources.getDimension(R.dimen.widget_course_padding)
                val paint = TextPaint().apply {
                    textSize = resources.getDimension(R.dimen.widget_course_details_size)
                }
                val items = RemoteViewsCompat.RemoteCollectionItems.Builder()
                    .setViewTypeCount(1)
                content.courses.forEachIndexed { index, course ->
                    val details = "${course.startTimeLabel} ${course.room}".trimEnd()
                    val label = if (paint.measureText(details) <= textWidth) {
                        details
                    } else {
                        course.startTimeLabel
                    }
                    items.addItem(index.toLong(), courseView(context, course, label))
                }
                RemoteViewsCompat.setRemoteAdapter(
                    context, views, id, R.id.widget_courses, items.build(),
                )
                manager.updateAppWidget(id, views)
            }

            // Inexact, non-wakeup alarms update visible data without an alarm permission.
            alarm.set(AlarmManager.RTC, content.nextUpdate, refresh)
        }

        private fun courseView(
            context: Context,
            course: WidgetCourse,
            details: String,
        ): RemoteViews {
            val color = course.name.codePoints().sum() % cardBackgrounds.size
            val textColor = context.getColor(cardTextColors[color])
            return RemoteViews(context.packageName, R.layout.widget_course).apply {
                setInt(R.id.widget_course, "setBackgroundResource", cardBackgrounds[color])
                setTextViewText(R.id.widget_course_name, course.name)
                setTextViewText(R.id.widget_course_details, details)
                setTextColor(R.id.widget_course_name, textColor)
                setTextColor(R.id.widget_course_details, textColor)
                setContentDescription(
                    R.id.widget_course,
                    "${course.name}，${course.timeLabel}，${course.room}",
                )
                setOnClickFillInIntent(R.id.widget_course, Intent())
            }
        }
    }
}

class WideTimetableWidget : TimetableWidget()
