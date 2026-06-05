package com.donsnotes.app.data.model

import com.google.gson.annotations.SerializedName

data class Meeting(
    @SerializedName("id") val id: String,
    @SerializedName("status") val status: MeetingStatus,
    @SerializedName("audio_url") val audioUrl: String? = null,
    @SerializedName("transcript") val transcript: String? = null,
    @SerializedName("summary") val summary: String? = null,
    @SerializedName("attendees") val attendees: List<Attendee> = emptyList(),
    @SerializedName("organizer_name") val organizerName: String? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    @SerializedName("user_id") val userId: String? = null
)
