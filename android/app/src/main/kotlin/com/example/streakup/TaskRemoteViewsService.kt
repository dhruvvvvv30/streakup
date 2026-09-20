package com.example.streakup

import android.content.Intent
import android.widget.RemoteViewsService

class TaskRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskRemoteViewsFactory(applicationContext, intent)
    }
}