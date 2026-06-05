package com.donsnotes.app.data.model

import com.google.gson.annotations.SerializedName

enum class MeetingStatus(val apiValue: String, val displayName: String) {
    @SerializedName("UPLOADING") UPLOADING("UPLOADING", "Uploading..."),
    @SerializedName("PENDING") PENDING("PENDING", "Pending"),
    @SerializedName("TRANSCRIBING") TRANSCRIBING("TRANSCRIBING", "Transcribing..."),
    @SerializedName("SUMMARIZING") SUMMARIZING("SUMMARIZING", "Summarizing..."),
    @SerializedName("COMPLETED") COMPLETED("COMPLETED", "Completed"),
    @SerializedName("SENT") SENT("SENT", "Email Sent"),
    @SerializedName("FAILED") FAILED("FAILED", "Failed");
}
