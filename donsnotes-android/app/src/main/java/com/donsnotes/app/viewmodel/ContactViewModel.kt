package com.donsnotes.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donsnotes.app.data.model.Attendee
import com.donsnotes.app.mock.MockApiService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Manages contacts, syncing from and saving to the backend.
 * Mirrors iOS ContactService.
 */
class ContactViewModel(application: Application) : AndroidViewModel(application) {

    private val mockApi = MockApiService()

    private val _savedContacts = MutableStateFlow<List<Attendee>>(emptyList())
    val savedContacts: StateFlow<List<Attendee>> = _savedContacts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun syncContacts() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val contacts = mockApi.fetchContacts()
                _savedContacts.value = contacts
            } catch (e: Exception) {
                // Silently fail like iOS does
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun saveContact(attendee: Attendee) {
        // Optimistically add to local list
        if (_savedContacts.value.none { it.email == attendee.email }) {
            _savedContacts.value = _savedContacts.value + attendee
        }

        viewModelScope.launch {
            try {
                mockApi.saveContact(attendee)
            } catch (e: Exception) {
                // Silently fail
            }
        }
    }
}
