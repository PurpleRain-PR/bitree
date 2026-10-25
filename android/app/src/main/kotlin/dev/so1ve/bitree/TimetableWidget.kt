package dev.so1ve.bitree

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.floor

class TimetableWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            updateAll(context)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TimetableWidget::class.java))
            if (ids.isEmpty()) return
            val views = RemoteViews(context.packageName, R.layout.timetable_widget)
            val open = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            val rows = intArrayOf(R.id.course_one, R.id.course_two, R.id.course_three)
            rows.forEach { views.setViewVisibility(it, View.GONE) }
            try {
                val file = File(context.filesDir, "schedule.json")
                if (!file.exists()) {
                    views.setTextViewText(R.id.widget_date, "今日课程")
                    views.setTextViewText(R.id.widget_message, "打开 BITree，添加课程或导入课表")
                } else {
                    val library = JSONObject(file.readText())
                    val schedule = library.getJSONObject("semesters")
                        .getJSONObject(library.getString("selectedTerm"))
                    val zone = TimeZone.getTimeZone("Asia/Shanghai")
                    val date = Calendar.getInstance(zone)
                    val weekday = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
                    val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { timeZone = zone }
                    val today = formatter.parse(formatter.format(date.time))!!
                    val first = formatter.parse(schedule.getString("firstMonday"))!!
                    val week = floor((today.time - first.time).toDouble() / (7 * 86400000L)).toInt() + 1
                    val names = arrayOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
                    views.setTextViewText(R.id.widget_date, "${date.get(Calendar.MONTH) + 1}月${date.get(Calendar.DAY_OF_MONTH)}日 ${names[weekday - 1]}")
                    val courses = schedule.getJSONArray("courses")
                    val todayCourses = (0 until courses.length()).map { courses.getJSONObject(it) }
                        .filter { course ->
                            course.optInt("weekday") == weekday &&
                                course.optInt("startSection") > 0 &&
                                course.getJSONArray("weeks").let { weeks ->
                                    (0 until weeks.length()).any { weeks.getInt(it) == week }
                                }
                        }.sortedBy { it.getInt("startSection") }
                    views.setTextViewText(R.id.widget_message,
                        if (todayCourses.isEmpty()) "今天没有课" else "第 $week 周，${todayCourses.size} 门课")
                    todayCourses.take(rows.size).forEachIndexed { index, course ->
                        val location = course.optString("room").ifBlank { "教室待定" }
                        val text = "${course.getInt("startSection")}–${course.getInt("endSection")} 节   ${course.getString("name")}\n$location"
                        views.setTextViewText(rows[index], text)
                        views.setViewVisibility(rows[index], View.VISIBLE)
                    }
                }
            } catch (error: Exception) {
                Log.w("BITree", "无法读取桌面组件的本地课表", error)
                views.setTextViewText(R.id.widget_date, "今日课程")
                views.setTextViewText(R.id.widget_message, "无法读取课表，点击打开 BITree")
            }
            ids.forEach { manager.updateAppWidget(it, views) }
        }
    }
}
