package com.donsnotes.app

import android.app.Application
import com.donsnotes.app.data.remote.RetrofitClient

class DonsNotesApp : Application() {

    // Toggle this to switch between Mock and Real API
    private val useMockApi = true

    override fun onCreate() {
        super.onCreate()

        if (!useMockApi) {
            // Configure for production API
            // RetrofitClient.setBaseUrl("https://api.donsnotes.com/")
        }

        // For local development against emulator-hosted backend:
        // RetrofitClient.setBaseUrl("http://10.0.2.2:8000/")
    }
}