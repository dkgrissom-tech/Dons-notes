package com.donsnotes.app.data.local

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "user_preferences")

class UserPreferences(private val context: Context) {

    companion object {
        private val USER_NAME_KEY = stringPreferencesKey("user_name")
        private val USER_EMAIL_KEY = stringPreferencesKey("user_email")
        private val AUTH_TOKEN_KEY = stringPreferencesKey("auth_token")
        private val DEMO_MODE_KEY = booleanPreferencesKey("demo_mode")
    }

    val userName: Flow<String> = context.dataStore.data.map { prefs ->
        prefs[USER_NAME_KEY] ?: ""
    }

    val userEmail: Flow<String> = context.dataStore.data.map { prefs ->
        prefs[USER_EMAIL_KEY] ?: ""
    }

    val authToken: Flow<String> = context.dataStore.data.map { prefs ->
        prefs[AUTH_TOKEN_KEY] ?: ""
    }

    val demoMode: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[DEMO_MODE_KEY] ?: false
    }

    suspend fun saveUserName(name: String) {
        context.dataStore.edit { prefs ->
            prefs[USER_NAME_KEY] = name
        }
    }

    suspend fun saveUserEmail(email: String) {
        context.dataStore.edit { prefs ->
            prefs[USER_EMAIL_KEY] = email
        }
    }

    suspend fun saveAuthToken(token: String) {
        context.dataStore.edit { prefs ->
            prefs[AUTH_TOKEN_KEY] = token
        }
    }

    suspend fun setDemoMode(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[DEMO_MODE_KEY] = enabled
        }
    }

    suspend fun isDemoMode(): Boolean {
        return context.dataStore.data.first()[DEMO_MODE_KEY] ?: false
    }

    suspend fun getUserNameSync(): String {
        return context.dataStore.data.first()[USER_NAME_KEY] ?: ""
    }

    suspend fun getAuthTokenSync(): String {
        return context.dataStore.data.first()[AUTH_TOKEN_KEY] ?: ""
    }

    suspend fun clearAll() {
        context.dataStore.edit { prefs ->
            prefs.clear()
        }
    }
}