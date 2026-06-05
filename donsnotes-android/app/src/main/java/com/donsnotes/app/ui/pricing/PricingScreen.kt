package com.donsnotes.app.ui.pricing

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PricingScreen(
    onDismiss: () -> Unit,
    isDemoMode: Boolean = false
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Plans & Pricing") },
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
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header
            Text(
                text = "Choose Your Plan",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold
            )

            Text(
                text = "Turn voice notes into polished recaps — instantly.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            // Free Plan — shows "Unlimited (Demo)" when demo mode is on
            if (isDemoMode) {
                PlanCard(
                    title = "Free (Demo)",
                    price = "Unlimited",
                    period = "demo",
                    description = "Owner & tester demo mode",
                    features = listOf(
                        "Unlimited transcription (demo override)",
                        "Full AI summaries",
                        "Custom email templates",
                        "Unlimited recipients per meeting"
                    ),
                    isRecommended = true,
                    buttonLabel = "Active",
                    buttonEnabled = false,
                    accentColor = MaterialTheme.colorScheme.tertiary
                )
            } else {
                PlanCard(
                    title = "Free",
                    price = "$0",
                    period = "forever",
                    description = "Try it out",
                    features = listOf(
                        "15 minutes of transcription per month",
                        "Basic AI summaries",
                        "Up to 5 attendees per meeting"
                    ),
                    isRecommended = false,
                    buttonLabel = "Current Plan",
                    buttonEnabled = false,
                    accentColor = MaterialTheme.colorScheme.outline
                )
            }

            // Monthly Plan (Recommended)
            PlanCard(
                title = "Monthly",
                price = "$4.99",
                period = "per month",
                description = "Unlimited transcription",
                features = listOf(
                    "Longer, detailed AI summaries",
                    "Custom email templates",
                    "Unlimited recipients per meeting",
                    "Priority processing"
                ),
                isRecommended = true,
                buttonLabel = "Subscribe",
                buttonEnabled = true,
                accentColor = MaterialTheme.colorScheme.primary
            )

            // Lifetime Plan
            PlanCard(
                title = "Lifetime",
                price = "$4.99",
                period = "one-time",
                description = "3 hours per month, forever",
                features = listOf(
                    "Full AI summaries",
                    "Up to 20 attendees per meeting",
                    "No recurring fees"
                ),
                isRecommended = false,
                buttonLabel = "Buy Now",
                buttonEnabled = true,
                accentColor = MaterialTheme.colorScheme.secondary
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "All plans include audio recording, transcript generation,\nand auto-email recaps to attendees.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun PlanCard(
    title: String,
    price: String,
    period: String,
    description: String,
    features: List<String>,
    isRecommended: Boolean,
    buttonLabel: String,
    buttonEnabled: Boolean,
    accentColor: androidx.compose.ui.graphics.Color
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(
            defaultElevation = if (isRecommended) 8.dp else 2.dp
        ),
        border = if (isRecommended) BorderStroke(2.dp, accentColor) else null,
        colors = CardDefaults.cardColors(
            containerColor = if (isRecommended) {
                accentColor.copy(alpha = 0.05f)
            } else {
                MaterialTheme.colorScheme.surface
            }
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Recommended badge
            if (isRecommended) {
                Surface(
                    color = accentColor,
                    shape = MaterialTheme.shapes.small
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(
                            Icons.Default.Star,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                        Text(
                            "RECOMMENDED",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onPrimary,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Title
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            // Price
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = price,
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = accentColor
                )
                Text(
                    text = "/ $period",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }

            // Description
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            HorizontalDivider()

            // Features
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                features.forEach { feature ->
                    Row(
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                            tint = accentColor
                        )
                        Text(
                            text = feature,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Action button
            Button(
                onClick = { /* TODO: handle purchase in a future update */ },
                modifier = Modifier.fillMaxWidth(),
                enabled = buttonEnabled,
                colors = ButtonDefaults.buttonColors(
                    containerColor = accentColor
                )
            ) {
                Text(
                    text = buttonLabel,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}