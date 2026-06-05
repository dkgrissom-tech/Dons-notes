package com.donsnotes.app.ui.contacts

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.donsnotes.app.data.model.Attendee
import com.donsnotes.app.viewmodel.ContactViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactPickerScreen(
    contactViewModel: ContactViewModel,
    selectedAttendees: List<Attendee>,
    onToggleSelection: (Attendee) -> Unit,
    onDismiss: () -> Unit
) {
    val contacts by contactViewModel.savedContacts.collectAsState()
    val isLoading by contactViewModel.isLoading.collectAsState()

    LaunchedEffect(Unit) {
        contactViewModel.syncContacts()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Select Contacts") },
                actions = {
                    TextButton(onClick = onDismiss) {
                        Text("Done")
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
            if (isLoading && contacts.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else if (contacts.isEmpty()) {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("No saved contacts", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        "Contacts are saved automatically when you add them to a meeting.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(16.dp)
                    )
                }
            } else {
                LazyColumn {
                    items(contacts, key = { it.email }) { contact ->
                        ListItem(
                            modifier = Modifier.clickable { onToggleSelection(contact) },
                            headlineContent = { Text(contact.name) },
                            supportingContent = { Text(contact.email) },
                            trailingContent = {
                                if (selectedAttendees.any { it.email == contact.email }) {
                                    Icon(
                                        Icons.Default.CheckCircle,
                                        contentDescription = "Selected",
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        )
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}
