package com.donsnotes.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donsnotes.app.data.local.UserPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Manages user profile (name, demo mode) stored locally via DataStore.
 * Mirrors iOS ProfileService + adds demo/owner mode.
 */
class ProfileViewModel(application: Application) : AndroidViewModel(application) {

    private val userPreferences = UserPreferences(application)

    private val _userName = MutableStateFlow("")
    val userName: StateFlow<String> = _userName.asStateFlow()

    private val _userEmail = MutableStateFlow("")
    val userEmail: StateFlow<String> = _userEmail.asStateFlow()

    private val _demoMode = MutableStateFlow(false)
    val demoMode: StateFlow<Boolean> = _demoMode.asStateFlow()

    init {
        viewModelScope.launch {
            _userName.value = userPreferences.getUserNameSync()
            _userEmail.value = userPreferences.userEmail.first()
            _demoMode.value = userPreferences.isDemoMode()
        }
    }

    fun saveName(name: String) {
        viewModelScope.launch {
            userPreferences.saveUserName(name)
            _userName.value = name
        }
    }

    fun saveEmail(email: String) {
        viewModelScope.launch {
            userPreferences.saveUserEmail(email)
            _userEmail.value = email
        }
    }

    /**
     * Toggle owner's demo mode — grants unlimited transcription usage.
     * Hidden: enabled by tapping the app title 7 times.
     */
    fun toggleDemoMode() {
        viewModelScope.launch {
            val newValue = !_demoMode.value
            _demoMode.value = newValue
            userPreferences.setDemoMode(newValue)
        }
    }
}