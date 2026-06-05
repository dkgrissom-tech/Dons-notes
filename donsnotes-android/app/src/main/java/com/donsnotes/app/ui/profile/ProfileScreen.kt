package com.donsnotes.app.ui.profile

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.donsnotes.app.viewmodel.ProfileViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    profileViewModel: ProfileViewModel,
    onDismiss: () -> Unit,
    onViewPlans: () -> Unit = {}
) {
    val currentName by profileViewModel.userName.collectAsState()
    val demoMode by profileViewModel.demoMode.collectAsState()
    var name by remember { mutableStateOf("") }

    LaunchedEffect(currentName) {
        name = currentName
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Profile Settings") },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text("Close")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // User info section
            Text(
                "User Information",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Display Name") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Button(
                onClick = {
                    profileViewModel.saveName(name.trim())
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = name.trim().isNotBlank()
            ) {
                Text("Save")
            }

            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(8.dp))

            // Plans / Subscription section
            Text(
                "Subscription",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (demoMode) {
                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    shape = MaterialTheme.shapes.small,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text("🌟", style = MaterialTheme.typography.titleLarge)
                        Column {
                            Text(
                                "Demo / Unlimited",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                            Text(
                                "Unlimited transcription for demo & testing",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                        }
                    }
                }
            } else {
                Text(
                    "You're on the Free plan (15 min/month).",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            OutlinedButton(
                onClick = onViewPlans,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("View Plans & Pricing")
            }
        }
    }
}