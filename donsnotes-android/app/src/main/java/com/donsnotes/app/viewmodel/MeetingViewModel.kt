package com.donsnotes.app.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.donsnotes.app.data.model.Attendee
import com.donsnotes.app.data.model.Meeting
import com.donsnotes.app.mock.MockApiService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Manages meeting list and meeting creation flow.
 * Mirrors iOS RecordingView + MeetingListView combined logic.
 */
class MeetingViewModel(application: Application) : AndroidViewModel(application) {

    private val mockApi = MockApiService()

    // Recording state
    private val _attendees = MutableStateFlow<List<Attendee>>(emptyList())
    val attendees: StateFlow<List<Attendee>> = _attendees.asStateFlow()

    private val _isUploading = MutableStateFlow(false)
    val isUploading: StateFlow<Boolean> = _isUploading.asStateFlow()

    // Meeting list state
    private val _meetings = MutableStateFlow<List<Meeting>>(emptyList())
    val meetings: StateFlow<List<Meeting>> = _meetings.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    // Selected meeting for detail
    private val _selectedMeeting = MutableStateFlow<Meeting?>(null)
    val selectedMeeting: StateFlow<Meeting?> = _selectedMeeting.asStateFlow()

    fun addAttendee(name: String, email: String) {
        if (name.isBlank() || email.isBlank()) return
        val attendee = Attendee(email = email, name = name)
        if (_attendees.value.none { it.email == attendee.email }) {
            _attendees.value = _attendees.value + attendee
        }
    }

    fun toggleAttendee(contact: Attendee) {
        _attendees.value = if (_attendees.value.any { it.email == contact.email }) {
            _attendees.value.filter { it.email != contact.email }
        } else {
            _attendees.value + contact
        }
    }

    fun removeAttendee(index: Int) {
        _attendees.value = _attendees.value.toMutableList().also { it.removeAt(index) }
    }

    fun clearAttendees() {
        _attendees.value = emptyList()
    }

    fun uploadMeeting(audioFilePath: String, organizerName: String?, onSuccess: () -> Unit, onError: (String) -> Unit) {
        _isUploading.value = true
        viewModelScope.launch {
            try {
                val audioFile = java.io.File(audioFilePath)
                mockApi.uploadMeeting(audioFile, _attendees.value, organizerName)
                _isUploading.value = false
                clearAttendees()
                onSuccess()
                refreshMeetings()
            } catch (e: Exception) {
                _isUploading.value = false
                onError(e.message ?: "Upload failed")
            }
        }
    }

    fun refreshMeetings() {
        _isLoading.value = true
        viewModelScope.launch {
            try {
                val fetched = mockApi.fetchMeetings()
                _meetings.value = fetched.sortedByDescending { it.createdAt }
            } catch (e: Exception) {
                // Silently fail
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun selectMeeting(meeting: Meeting) {
        _selectedMeeting.value = meeting
    }

    fun refreshMeetingDetail() {
        val meeting = _selectedMeeting.value ?: return
        viewModelScope.launch {
            try {
                _selectedMeeting.value = mockApi.fetchMeetingDetails(meeting.id)
            } catch (e: Exception) {
                // Silently fail
            }
        }
    }

    fun sendRecapEmail(onComplete: () -> Unit) {
        val meeting = _selectedMeeting.value ?: return
        viewModelScope.launch {
            try {
                mockApi.sendRecapEmail(meeting.id)
                refreshMeetingDetail()
            } catch (e: Exception) {
                // Silently fail
            } finally {
                onComplete()
            }
        }
    }
}
