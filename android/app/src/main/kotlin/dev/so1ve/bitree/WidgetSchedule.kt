package dev.so1ve.bitree

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.floor

private val sectionTimes = listOf(
    480 to 525, 530 to 575, 595 to 640, 645 to 690, 695 to 740,
    800 to 845, 850 to 895, 915 to 960, 965 to 1010, 1015 to 1060,
    1110 to 1155, 1160 to 1205, 1210 to 1255,
)
private val weekdays = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

internal data class WidgetCourse(
    val name: String,
    val room: String,
    val start: Int,
    val end: Int,
) {
    val timeLabel: String
        get() = "${clockTime(start)}–${clockTime(end)}"
}

internal data class WidgetContent(
    val heading: String,
    val courses: List<WidgetCourse>,
    val emptyMessage: String,
    val tomorrow: Boolean,
    val nextUpdate: Long,
)

internal fun readWidgetContent(context: Context): WidgetContent {
    val zone = TimeZone.getTimeZone("Asia/Shanghai")
    val now = Calendar.getInstance(zone)
    val today = (now.clone() as Calendar).apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }
    val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DATE, 1) }
    val evening = (today.clone() as Calendar).apply { set(Calendar.HOUR_OF_DAY, 21) }
    var nextUpdate = tomorrow.timeInMillis
    if (evening.after(now)) nextUpdate = evening.timeInMillis
    val todayHeading = "今天${weekdays[weekday(today) - 1]}"

    try {
        val file = File(context.filesDir, "schedule.json")
        if (!file.exists()) {
            return WidgetContent(
                todayHeading, emptyList(), context.getString(R.string.widget_no_schedule),
                false, nextUpdate,
            )
        }
        val library = JSONObject(file.readText())
        val schedule = library.getJSONObject("semesters")
            .getJSONObject(library.getString("selectedTerm"))
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply {
            timeZone = zone
            isLenient = false
        }
        val firstMonday = formatter.parse(schedule.getString("firstMonday"))!!
        val rows = schedule.getJSONArray("courses")
        val courses = (0 until rows.length()).map { rows.getJSONObject(it) }

        fun coursesOn(date: Calendar): List<WidgetCourse> {
            val offset = floor(
                (date.timeInMillis - firstMonday.time).toDouble() / (7 * 86400000L),
            ).toInt()
            val week = if (offset >= 0) offset + 1 else offset
            return courses.filter { course ->
                val weeks = course.getJSONArray("weeks")
                !course.isNull("startSection") &&
                    !course.isNull("endSection") &&
                    course.optInt("weekday") == weekday(date) &&
                    (0 until weeks.length()).any { weeks.getInt(it) == week }
            }.map { course ->
                WidgetCourse(
                    course.getString("name"),
                    course.getString("room"),
                    sectionTimes[course.getInt("startSection") - 1].first,
                    sectionTimes[course.getInt("endSection") - 1].second,
                )
            }.sortedWith(compareBy({ it.start }, { it.name }))
        }

        val todayCourses = coursesOn(today)
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val remaining = todayCourses.filter { it.end > minute }
        for (course in remaining) {
            val end = today.timeInMillis + course.end * 60000L
            if (end < nextUpdate) nextUpdate = end
        }
        val showTomorrow = minute >= 21 * 60 && remaining.isEmpty()
        val displayed = if (showTomorrow) coursesOn(tomorrow) else remaining
        val emptyMessage = when {
            showTomorrow -> R.string.widget_tomorrow_empty
            todayCourses.isEmpty() -> R.string.widget_today_empty
            else -> R.string.widget_finished
        }
        return WidgetContent(
            if (showTomorrow) "明天${weekdays[weekday(tomorrow) - 1]}" else todayHeading,
            displayed,
            context.getString(emptyMessage),
            showTomorrow,
            nextUpdate,
        )
    } catch (error: Exception) {
        Log.w("BITree", "无法读取桌面组件的本地课表", error)
        return WidgetContent(
            todayHeading, emptyList(), context.getString(R.string.widget_read_error),
            false, nextUpdate,
        )
    }
}

private fun weekday(date: Calendar): Int = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1

private fun clockTime(minutes: Int): String =
    String.format(Locale.ROOT, "%02d:%02d", minutes / 60, minutes % 60)
