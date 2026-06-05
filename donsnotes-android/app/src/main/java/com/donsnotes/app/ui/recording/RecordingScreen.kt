package com.donsnotes.app.ui.recording

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.donsnotes.app.data.model.Attendee
import com.donsnotes.app.service.AudioRecorder
import com.donsnotes.app.viewmodel.ContactViewModel
import com.donsnotes.app.viewmodel.MeetingViewModel
import com.donsnotes.app.viewmodel.ProfileViewModel
import kotlinx.coroutines.delay
import java.util.Locale

/**
 * Parses a spoken utterance like "Jane Smith, jane@example.com"
 * into (name, email). The last token containing "@" is the email;
 * everything before it is the name.
 */
private fun parseAttendeeFromSpeech(transcript: String): Pair<String, String> {
    val parts = transcript.split(Regex("[,;\\s]+"))
    val emailIndex = parts.indexOfLast { it.contains("@") }

    if (emailIndex == -1) {
        // No email found — put everything as name
        return transcript.trim() to ""
    }

    val email = parts[emailIndex].trim().removeSuffix(".").removeSuffix(",")
    val name = parts.subList(0, emailIndex).joinToString(" ").trim()
        .removeSuffix(",").removeSuffix(".").trim()

    return name.ifBlank { email.substringBefore("@") } to email
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordingScreen(
    meetingViewModel: MeetingViewModel,
    contactViewModel: ContactViewModel,
    profileViewModel: ProfileViewModel,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val attendees by meetingViewModel.attendees.collectAsState()
    val savedContacts by contactViewModel.savedContacts.collectAsState()
    val userName by profileViewModel.userName.collectAsState()
    val isUploading by meetingViewModel.isUploading.collectAsState()

    var newAttendeeName by remember { mutableStateOf("") }
    var newAttendeeEmail by remember { mutableStateOf("") }
    var isRecording by remember { mutableStateOf(false) }
    var recordingComplete by remember { mutableStateOf(false) }
    var audioFilePath by remember { mutableStateOf("") }

    // === Speech recognition state ===
    var isListening by remember { mutableStateOf(false) }
    var partialTranscript by remember { mutableStateOf("") }
    var speechError by remember { mutableStateOf<String?>(null) }

    // Audio recorder
    val audioRecorder = remember { AudioRecorder(context) }

    // SpeechRecognizer for voice input
    val speechRecognizer = remember { SpeechRecognizer.createSpeechRecognizer(context) }

    // Permission launcher for audio recording
    val audioPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            isListening = true
        }
    }

    // Speech recognizer listener — parses name+email from a single utterance
    LaunchedEffect(isListening) {
        if (isListening) {
            speechError = null
            partialTranscript = ""
            val intent = android.content.Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_PROMPT, "Say the attendee name and email, like: Jane Smith, jane@example.com")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            speechRecognizer.setRecognitionListener(object : RecognitionListener {
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(RecognizerIntent.EXTRA_RESULTS)
                    if (!matches.isNullOrEmpty()) {
                        val transcript = matches[0]
                        val (name, email) = parseAttendeeFromSpeech(transcript)

                        if (email.isNotBlank()) {
                            // Auto-fill and auto-add
                            newAttendeeName = name
                            newAttendeeEmail = email
                            meetingViewModel.addAttendee(name, email)
                            contactViewModel.saveContact(Attendee(email = email, name = name))
                            newAttendeeName = ""
                            newAttendeeEmail = ""
                            partialTranscript = ""
                        } else {
                            // Put recognized text into the name field for user to complete
                            newAttendeeName = transcript
                            partialTranscript = ""
                        }
                    }
                    isListening = false
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(RecognizerIntent.EXTRA_RESULTS)
                    if (!matches.isNullOrEmpty()) {
                        partialTranscript = matches[0]
                    }
                }

                override fun onError(error: Int) {
                    speechError = when (error) {
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected. Please try again."
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Timed out waiting for speech."
                        SpeechRecognizer.ERROR_NETWORK -> "Network error. Check your connection."
                        SpeechRecognizer.ERROR_AUDIO -> "Audio error. Check microphone."
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer busy. Try again."
                        else -> "Recognition error. Please try again."
                    }
                    isListening = false
                    partialTranscript = ""
                }

                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            speechRecognizer.startListening(intent)
        }
    }

    // Cleanup
    DisposableEffect(Unit) {
        onDispose {
            if (audioRecorder.isRecording) {
                audioRecorder.cancelRecording()
            }
            speechRecognizer.destroy()
        }
    }

    LaunchedEffect(Unit) {
        contactViewModel.syncContacts()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isRecording) "Recording" else "New Meeting") },
                navigationIcon = {
                    TextButton(onClick = {
                        if (isRecording) audioRecorder.cancelRecording()
                        onDismiss()
                    }) {
                        Text("Cancel")
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
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (!isRecording && !recordingComplete) {
                    // ===== SETUP PHASE: Add Attendees =====
                    Text("Attendee Sign-In", style = MaterialTheme.typography.headlineMedium)

                    if (userName.isNotBlank()) {
                        Text(
                            "Organizer: $userName",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    // Quick Add from contacts
                    if (savedContacts.isNotEmpty()) {
                        Text(
                            "Quick Add from Contacts",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            savedContacts.take(6).forEach { contact ->
                                FilterChip(
                                    selected = attendees.any { it.email == contact.email },
                                    onClick = { meetingViewModel.toggleAttendee(contact) },
                                    label = { Text(contact.name, maxLines = 1) }
                                )
                            }
                        }
                    }

                    // Manual input: Name field
                    OutlinedTextField(
                        value = newAttendeeName,
                        onValueChange = { newAttendeeName = it },
                        label = { Text("Name") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    // Manual input: Email field
                    OutlinedTextField(
                        value = newAttendeeEmail,
                        onValueChange = { newAttendeeEmail = it },
                        label = { Text("Email") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                    )

                    // Manual Add button
                    Button(
                        onClick = {
                            meetingViewModel.addAttendee(newAttendeeName, newAttendeeEmail)
                            contactViewModel.saveContact(Attendee(email = newAttendeeEmail, name = newAttendeeName))
                            newAttendeeName = ""
                            newAttendeeEmail = ""
                        },
                        enabled = newAttendeeName.isNotBlank() && newAttendeeEmail.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Add Attendee")
                    }

                    // === "Speak to Add" button ===
                    OutlinedButton(
                        onClick = {
                            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                                == PackageManager.PERMISSION_GRANTED
                            ) {
                                isListening = true
                            } else {
                                audioPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !isListening
                    ) {
                        Icon(
                            Icons.Default.Mic,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Speak to Add — say \"Name, email@example.com\"")
                    }

                    // Error from speech recognition
                    speechError?.let { error ->
                        Snackbar(
                            modifier = Modifier.fillMaxWidth(),
                            action = {
                                TextButton(onClick = { speechError = null }) {
                                    Text("Dismiss")
                                }
                            }
                        ) {
                            Text(error)
                        }
                    }

                    // Attendee list
                    if (attendees.isNotEmpty()) {
                        Text("Attendees", style = MaterialTheme.typography.titleMedium,
                             fontWeight = FontWeight.SemiBold)
                        LazyColumn(modifier = Modifier.weight(1f)) {
                            itemsIndexed(attendees) { index, attendee ->
                                ListItem(
                                    headlineContent = { Text(attendee.name) },
                                    supportingContent = { Text(attendee.email) },
                                    trailingContent = {
                                        TextButton(onClick = { meetingViewModel.removeAttendee(index) }) {
                                            Text("Remove", color = MaterialTheme.colorScheme.error)
                                        }
                                    }
                                )
                                HorizontalDivider()
                            }
                        }
                    } else {
                        Box(
                            modifier = Modifier.weight(1f).fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                "Add attendees to start",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    // Start Recording button
                    Button(
                        onClick = {
                            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                                == PackageManager.PERMISSION_GRANTED
                            ) {
                                kotlinx.coroutines.MainScope().launch {
                                    audioRecorder.startRecording().onSuccess { isRecording = true }
                                }
                            } else {
                                audioPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = attendees.isNotEmpty()
                    ) {
                        Text("Start Recording")
                    }

                } else if (isRecording) {
                    // ===== RECORDING PHASE =====
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Recording...", style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.error)

                            Spacer(modifier = Modifier.height(16.dp))

                            // Animated dots
                            var dots by remember { mutableStateOf("") }
                            LaunchedEffect(Unit) {
                                while (true) {
                                    dots = when (dots.length) {
                                        0 -> "."
                                        1 -> ".."
                                        else -> "..."
                                    }
                                    delay(500)
                                }
                            }
                            Text(dots, style = MaterialTheme.typography.headlineLarge)

                            Spacer(modifier = Modifier.height(32.dp))

                            FilledTonalButton(
                                onClick = {
                                    kotlinx.coroutines.MainScope().launch {
                                        audioRecorder.stopRecording().onSuccess { file ->
                                            audioFilePath = file.absolutePath
                                            isRecording = false
                                            recordingComplete = true
                                        }
                                    }
                                },
                                colors = ButtonDefaults.filledTonalButtonColors(
                                    containerColor = MaterialTheme.colorScheme.error
                                )
                            ) {
                                Icon(Icons.Default.Stop, contentDescription = null)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Stop Recording")
                            }
                        }
                    }

                } else if (recordingComplete) {
                    // ===== UPLOAD PHASE =====
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("✓", style = MaterialTheme.typography.headlineLarge,
                                color = MaterialTheme.colorScheme.primary)
                            Text("Recording Saved", style = MaterialTheme.typography.headlineMedium)

                            Spacer(modifier = Modifier.height(8.dp))

                            Text(
                                "${attendees.size} attendees will receive the recap.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )

                            Spacer(modifier = Modifier.height(32.dp))

                            Button(
                                onClick = {
                                    meetingViewModel.uploadMeeting(
                                        audioFilePath = audioFilePath,
                                        organizerName = userName.takeIf { it.isNotBlank() },
                                        onSuccess = { onDismiss() },
                                        onError = { /* TODO: snackbar */ }
                                    )
                                },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isUploading
                            ) {
                                if (isUploading) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        color = MaterialTheme.colorScheme.onPrimary,
                                        strokeWidth = 2.dp
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                }
                                Text("Upload & Process")
                            }

                            TextButton(onClick = {
                                recordingComplete = false
                                audioFilePath = ""
                            }) {
                                Text("Discard Recording", color = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }

            // ===== Speech Recognition Overlay =====
            if (isListening) {
                SpeechRecognitionOverlay(
                    partialTranscript = partialTranscript,
                    onCancel = {
                        speechRecognizer.cancel()
                        isListening = false
                        partialTranscript = ""
                    }
                )
            }
        }
    }
}

/**
 * Full-screen overlay shown while SpeechRecognizer is listening.
 * Displays a waveform animation, "Listening..." text, partial transcript,
 * and a cancel button.
 */
@Composable
fun SpeechRecognitionOverlay(
    partialTranscript: String,
    onCancel: () -> Unit
) {
    // Animated waveform bars
    val infiniteTransition = rememberInfiniteTransition(label = "waveform")
    val barHeights = List(7) { index ->
        infiniteTransition.animateFloat(
            initialValue = 0.3f,
            targetValue = 1.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 600 + index * 100, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "bar$index"
        )
    }

    Surface(
        color = MaterialTheme.colorScheme.scrim.copy(alpha = 0.85f),
        modifier = Modifier.fillMaxSize()
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.padding(32.dp)
            ) {
                // Waveform animation
                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp)
                ) {
                    val barWidth = size.width / (barHeights.size * 2f)
                    val midY = size.height / 2f
                    barHeights.forEachIndexed { index, heightState ->
                        val barHeight = heightState.value * midY * 1.5f
                        drawRect(
                            color = Color.White,
                            topLeft = Offset(
                                x = barWidth * (index * 2 + 0.5f),
                                y = midY - barHeight / 2f
                            ),
                            size = androidx.compose.ui.geometry.Size(
                                width = barWidth,
                                height = barHeight
                            )
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // "Listening..." text
                Text(
                    text = "Listening...",
                    style = MaterialTheme.typography.headlineMedium,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Hint
                Text(
                    text = "Say: \"Name, email@example.com\"",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )

                // Partial transcript (live updates while speaking)
                if (partialTranscript.isNotBlank()) {
                    Spacer(modifier = Modifier.height(24.dp))
                    Surface(
                        color = Color.White.copy(alpha = 0.15f),
                        shape = MaterialTheme.shapes.medium
                    ) {
                        Text(
                            text = partialTranscript,
                            style = MaterialTheme.typography.bodyLarge,
                            color = Color.White,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(48.dp))

                // Cancel button
                OutlinedButton(
                    onClick = onCancel,
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color.White
                    )
                ) {
                    Text("Cancel")
                }
            }
        }
    }
}