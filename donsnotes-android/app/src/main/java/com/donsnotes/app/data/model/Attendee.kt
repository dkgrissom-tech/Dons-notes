package com.donsnotes.app.data.model

import com.google.gson.annotations.SerializedName

data class Attendee(
    @SerializedName("email") val email: String,
    @SerializedName("name") val name: String,
    @SerializedName("id") val id: String? = null,
    @SerializedName("meeting_id") val meetingId: String? = null
)
