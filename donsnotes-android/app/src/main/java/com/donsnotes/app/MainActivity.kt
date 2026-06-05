package com.donsnotes.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.donsnotes.app.ui.contacts.ContactPickerScreen
import com.donsnotes.app.ui.meetings.MeetingDetailScreen
import com.donsnotes.app.ui.meetings.MeetingListScreen
import com.donsnotes.app.ui.pricing.PricingScreen
import com.donsnotes.app.ui.profile.ProfileScreen
import com.donsnotes.app.ui.recording.RecordingScreen
import com.donsnotes.app.ui.theme.DonsNotesTheme
import com.donsnotes.app.viewmodel.ContactViewModel
import com.donsnotes.app.viewmodel.MeetingViewModel
import com.donsnotes.app.viewmodel.ProfileViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            DonsNotesTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    DonsNotesApp()
                }
            }
        }
    }
}

@Composable
fun DonsNotesApp() {
    val meetingViewModel: MeetingViewModel = viewModel()
    val contactViewModel: ContactViewModel = viewModel()
    val profileViewModel: ProfileViewModel = viewModel()

    val demoMode by profileViewModel.demoMode.collectAsState()

    // Simple navigation state machine
    var currentScreen by remember { mutableStateOf("meetings") }
    var showProfile by remember { mutableStateOf(false) }
    var showRecording by remember { mutableStateOf(false) }
    var showContactPicker by remember { mutableStateOf(false) }
    var showPricing by remember { mutableStateOf(false) }

    // Meeting list screen
    if (currentScreen == "meetings" && !showProfile && !showRecording && !showContactPicker && !showPricing) {
        MeetingListScreen(
            viewModel = meetingViewModel,
            onStartRecording = { showRecording = true },
            onOpenProfile = { showProfile = true },
            onMeetingSelected = {
                meetingViewModel.selectMeeting(it)
                currentScreen = "meeting_detail"
            },
            isDemoMode = demoMode,
            onToggleDemoMode = { profileViewModel.toggleDemoMode() }
        )
    }

    // Recording screen
    if (showRecording) {
        RecordingScreen(
            meetingViewModel = meetingViewModel,
            contactViewModel = contactViewModel,
            profileViewModel = profileViewModel,
            onDismiss = {
                showRecording = false
                meetingViewModel.clearAttendees()
                meetingViewModel.refreshMeetings()
            }
        )
    }

    // Meeting detail screen
    if (currentScreen == "meeting_detail") {
        MeetingDetailScreen(
            viewModel = meetingViewModel,
            onBack = { currentScreen = "meetings" }
        )
    }

    // Profile screen
    if (showProfile) {
        ProfileScreen(
            profileViewModel = profileViewModel,
            onDismiss = { showProfile = false },
            onViewPlans = {
                showProfile = false
                showPricing = true
            }
        )
    }

    // Pricing / Plans screen
    if (showPricing) {
        PricingScreen(
            onDismiss = { showPricing = false },
            isDemoMode = demoMode
        )
    }

    // Contact picker screen
    if (showContactPicker) {
        val selectedAttendees by meetingViewModel.attendees.collectAsState()
        ContactPickerScreen(
            contactViewModel = contactViewModel,
            selectedAttendees = selectedAttendees,
            onToggleSelection = { contact -> meetingViewModel.toggleAttendee(contact) },
            onDismiss = { showContactPicker = false }
        )
    }
}