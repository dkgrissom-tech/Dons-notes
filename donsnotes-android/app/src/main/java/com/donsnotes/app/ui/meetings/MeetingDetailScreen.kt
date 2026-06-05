package com.donsnotes.app.ui.meetings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.donsnotes.app.data.model.Meeting
import com.donsnotes.app.data.model.MeetingStatus
import com.donsnotes.app.ui.theme.StatusGreen
import com.donsnotes.app.viewmodel.MeetingViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeetingDetailScreen(
    viewModel: MeetingViewModel,
    onBack: () -> Unit
) {
    val meeting by viewModel.selectedMeeting.collectAsState()
    val currentMeeting = meeting ?: run {
        onBack()
        return
    }

    var isSendingEmail by remember { mutableStateOf(false) }

    // Auto-refresh while processing
    LaunchedEffect(currentMeeting.status) {
        if (currentMeeting.status in listOf(
                MeetingStatus.UPLOADING,
                MeetingStatus.PENDING,
                MeetingStatus.TRANSCRIBING,
                MeetingStatus.SUMMARIZING
            )
        ) {
            while (true) {
                kotlinx.coroutines.delay(5000)
                viewModel.refreshMeetingDetail()
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Meeting Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("←", style = MaterialTheme.typography.titleLarge)
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Status
            StatusBadge(status = currentMeeting.status)

            // Date
            Text(
                text = currentMeeting.createdAt?.take(10) ?: "Unknown date",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // Organizer
            if (!currentMeeting.organizerName.isNullOrBlank()) {
                Text(
                    text = "Organizer",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = currentMeeting.organizerName,
                    style = MaterialTheme.typography.bodyLarge
                )
            }

            // Attendees
            Text(
                text = "Attendees",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            currentMeeting.attendees.forEach { attendee ->
                Text(
                    text = "${attendee.name} (${attendee.email})",
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            // Summary
            if (!currentMeeting.summary.isNullOrBlank()) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = MaterialTheme.shapes.medium
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Summary",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = currentMeeting.summary,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            // Transcript
            if (!currentMeeting.transcript.isNullOrBlank()) {
                Text(
                    text = "Transcript",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = currentMeeting.transcript,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Send Email button
            if (currentMeeting.status == MeetingStatus.COMPLETED) {
                Button(
                    onClick = {
                        isSendingEmail = true
                        viewModel.sendRecapEmail {
                            isSendingEmail = false
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSendingEmail,
                    colors = ButtonDefaults.buttonColors(containerColor = StatusGreen)
                ) {
                    if (isSendingEmail) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = MaterialTheme.colorScheme.onPrimary,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text("Send Recap Email")
                    }
                }
            }
        }
    }
}