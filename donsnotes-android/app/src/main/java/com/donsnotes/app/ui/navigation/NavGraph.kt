package com.donsnotes.app.ui.navigation

sealed class Screen(val route: String) {
    object MeetingList : Screen("meetings")
    object Recording : Screen("recording")
    object MeetingDetail : Screen("meeting_detail")
    object ContactPicker : Screen("contact_picker")
    object Profile : Screen("profile")
}