package com.example.streakup

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class StreakWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "com.example.streakup.TOGGLE_TASK"

        fun updateWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.streak_widget)

            val streak = prefs.getInt("streak_count", 0)
            val tasks = WidgetData.loadTasks(context)
            val done = tasks.count { it.done }

            // Left panel: title, flame + number, note, pill (one bitmap)
            views.setImageViewBitmap(R.id.left_art, WidgetArt.leftPanel(context, streak))
            views.setContentDescription(R.id.left_art, "StreakUp, $streak day streak")

            // Header: "Today" and "2/4"
            views.setImageViewBitmap(
                R.id.today_label,
                WidgetArt.textBitmap(context, "Today", 20f, 0xFF14143F.toInt(), 0f, true)
            )
            views.setImageViewBitmap(
                R.id.task_progress,
                WidgetArt.textBitmap(context, "$done/${tasks.size}", 15f, 0xFF7C7CA8.toInt())
            )

            // Empty state
            val fresh = WidgetData.isFresh(context)
            views.setTextViewText(
                R.id.empty_view,
                if (fresh) "No tasks for today" else "Open StreakUp to refresh"
            )
            views.setEmptyView(R.id.task_list, R.id.empty_view)

            // Task list adapter
            val serviceIntent = Intent(context, TaskRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.task_list, serviceIntent)

            // Row tap -> toggle broadcast
            val toggleIntent = Intent(context, StreakWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE
            }
            val togglePending = PendingIntent.getBroadcast(
                context, 0, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.task_list, togglePending)

            // Tap on the left panel or "Today" header opens the app
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val openApp = PendingIntent.getActivity(
                    context, 1, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.left_art, openApp)
                views.setOnClickPendingIntent(R.id.task_header, openApp)
            }

            mgr.updateAppWidget(appWidgetId, views)
            mgr.notifyAppWidgetViewDataChanged(appWidgetId, R.id.task_list)
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, mgr, id)
        if (WidgetData.needsRefresh(context)) {
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("streakupwidget://refresh")
            ).send()
        }
    }

    // Re-render when the user resizes the widget (task titles depend on the width)
    override fun onAppWidgetOptionsChanged(
        context: Context, mgr: AppWidgetManager, appWidgetId: Int, newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, mgr, appWidgetId, newOptions)
        updateWidget(context, mgr, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra("task_id") ?: return

        val prefs = HomeWidgetPlugin.getData(context)

        val arr = JSONArray(prefs.getString("today_tasks", "[]") ?: "[]")
        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.getString("id") == taskId) obj.put("done", !obj.getBoolean("done"))
        }

        val pending = JSONArray(prefs.getString("pending_toggles", "[]") ?: "[]")
        var alreadyPending = false
        for (i in 0 until pending.length()) if (pending.getString(i) == taskId) alreadyPending = true
        if (!alreadyPending) pending.put(taskId)

        prefs.edit()
            .putString("today_tasks", arr.toString())
            .putString("pending_toggles", pending.toString())
            .apply()

        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, StreakWidgetProvider::class.java))
        for (id in ids) updateWidget(context, mgr, id)

        HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("streakupwidget://toggle?taskId=$taskId")
        ).send()
    }
}