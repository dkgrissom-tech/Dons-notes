package com.donsnotes.app.ui.meetings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.donsnotes.app.data.model.Meeting
import com.donsnotes.app.data.model.MeetingStatus
import com.donsnotes.app.ui.theme.StatusBlue
import com.donsnotes.app.ui.theme.StatusGreen
import com.donsnotes.app.ui.theme.StatusRed
import com.donsnotes.app.viewmodel.MeetingViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeetingListScreen(
    viewModel: MeetingViewModel,
    onStartRecording: () -> Unit,
    onOpenProfile: () -> Unit,
    onMeetingSelected: (Meeting) -> Unit,
    isDemoMode: Boolean = false,
    onToggleDemoMode: () -> Unit = {}
) {
    val meetings by viewModel.meetings.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    // Tap counter for hidden demo mode easter egg (7 taps on title)
    var titleTapCount by remember { mutableStateOf(0) }
    var showDemoSnackbar by remember { mutableStateOf(false) }

    // Show snackbar briefly when demo mode toggles
    LaunchedEffect(showDemoSnackbar) {
        if (showDemoSnackbar) {
            kotlinx.coroutines.delay(2000)
            showDemoSnackbar = false
        }
    }

    LaunchedEffect(Unit) {
        viewModel.refreshMeetings()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "Don's Notes",
                            modifier = Modifier.clickable {
                                titleTapCount++
                                if (titleTapCount >= 7) {
                                    onToggleDemoMode()
                                    titleTapCount = 0
                                    showDemoSnackbar = true
                                }
                            }
                        )
                        if (isDemoMode) {
                            Surface(
                                color = MaterialTheme.colorScheme.tertiary,
                                shape = MaterialTheme.shapes.small
                            ) {
                                Text(
                                    text = "DEMO",
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onTertiary,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                },
                actions = {
                    IconButton(onClick = onOpenProfile) {
                        Text("⚙", style = MaterialTheme.typography.titleLarge)
                    }
                    IconButton(onClick = onStartRecording) {
                        Text("+", style = MaterialTheme.typography.headlineLarge)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { viewModel.refreshMeetings() }) {
                        Text("↻", style = MaterialTheme.typography.titleLarge)
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (isLoading && meetings.isEmpty()) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center)
                )
            } else if (meetings.isEmpty()) {
                Text(
                    text = "No meetings yet",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(meetings, key = { it.id }) { meeting ->
                        MeetingListItem(
                            meeting = meeting,
                            onClick = { onMeetingSelected(meeting) }
                        )
                    }
                }
            }

            // Snackbar for demo mode toggle feedback
            if (showDemoSnackbar) {
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp)
                ) {
                    Text(
                        if (isDemoMode) "🌟 Demo mode ON — Unlimited transcription"
                        else "Demo mode OFF"
                    )
                }
            }
        }
    }
}

@Composable
fun MeetingListItem(
    meeting: Meeting,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = meeting.createdAt?.take(10) ?: "Unknown date",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${meeting.attendees.size} attendees",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            StatusBadge(status = meeting.status)
        }
    }
}

@Composable
fun StatusBadge(status: MeetingStatus) {
    val (bgColor, textColor) = when (status) {
        MeetingStatus.COMPLETED, MeetingStatus.SENT -> StatusGreen to StatusGreen
        MeetingStatus.FAILED -> StatusRed to StatusRed
        else -> StatusBlue to StatusBlue
    }

    Surface(
        color = bgColor.copy(alpha = 0.15f),
        shape = MaterialTheme.shapes.small
    ) {
        Text(
            text = status.displayName,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = textColor,
            fontWeight = FontWeight.Medium
        )
    }
}