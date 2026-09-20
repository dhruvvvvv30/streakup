package com.example.streakup

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

data class WidgetTask(val id: String, val title: String, val done: Boolean)

object WidgetData {
    private fun today(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Data pushed by Dart is only valid for the day it was pushed. */
    fun isFresh(context: Context): Boolean =
        HomeWidgetPlugin.getData(context).getString("data_date", "") == today()

    fun needsRefresh(context: Context): Boolean {
        if (!isFresh(context)) return true
        val last = HomeWidgetPlugin.getData(context)
            .getString("last_refresh", "0")?.toLongOrNull() ?: 0L
        return System.currentTimeMillis() - last > 15 * 60 * 1000
    }

    fun loadTasks(context: Context): List<WidgetTask> {
        if (!isFresh(context)) return emptyList()
        val raw = HomeWidgetPlugin.getData(context).getString("today_tasks", "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                WidgetTask(o.getString("id"), o.optString("title", ""), o.optBoolean("done", false))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}

class TaskRemoteViewsFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val appWidgetId =
        intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

    private var tasks: List<WidgetTask> = emptyList()
    private var titleMaxDp = 120f

    /** Width available for a task title, from the widget's current size. */
    private fun computeTitleWidth(): Float = try {
        val opts = AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
        val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        if (w <= 0) 120f else max(60f, (w - 49f) * 16f / 25f - 48f)
    } catch (e: Exception) {
        120f
    }

    private fun reload() {
        tasks = WidgetData.loadTasks(context)
        titleMaxDp = computeTitleWidth()
    }

    override fun onCreate() = reload()
    override fun onDataSetChanged() = reload()
    override fun onDestroy() {}
    override fun getCount(): Int = tasks.size
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long =
        tasks.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
    override fun hasStableIds(): Boolean = true
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.task_item)
        val task = tasks.getOrNull(position) ?: return row

        row.setImageViewBitmap(
            R.id.task_title,
            WidgetArt.textBitmap(context, task.title, 15f, 0xFF14143F.toInt(), titleMaxDp)
        )
        row.setContentDescription(R.id.task_title, task.title)
        row.setImageViewResource(
            R.id.task_checkbox,
            if (task.done) R.drawable.ic_checkbox_checked else R.drawable.ic_checkbox_unchecked
        )
        row.setInt(
            R.id.task_row,
            "setBackgroundResource",
            if (task.done) R.drawable.task_row_background_active else R.drawable.task_row_background
        )

        val fillIn = Intent().apply { putExtra("task_id", task.id) }
        row.setOnClickFillInIntent(R.id.task_row, fillIn)
        row.setOnClickFillInIntent(R.id.task_checkbox, fillIn)
        row.setOnClickFillInIntent(R.id.task_title, fillIn)
        return row
    }
}