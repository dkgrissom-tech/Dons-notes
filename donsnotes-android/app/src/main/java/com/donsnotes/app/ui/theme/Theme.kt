package com.donsnotes.app.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val LightColorScheme = lightColorScheme(
    primary = Blue600,
    onPrimary = TextOnPrimary,
    primaryContainer = Blue500,
    secondary = Blue700,
    background = SurfaceLight,
    surface = CardLight,
    onBackground = TextPrimary,
    onSurface = TextPrimary,
    error = StatusRed
)

private val DarkColorScheme = darkColorScheme(
    primary = Blue500,
    onPrimary = TextOnPrimary,
    primaryContainer = Blue800,
    secondary = Blue600,
    background = SurfaceDark,
    surface = CardDark,
    onBackground = TextOnPrimary,
    onSurface = TextOnPrimary,
    error = StatusRed
)

@Composable
fun DonsNotesTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
