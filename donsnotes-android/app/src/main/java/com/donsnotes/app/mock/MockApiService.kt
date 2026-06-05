package com.donsnotes.app.mock

import com.donsnotes.app.data.model.Attendee
import com.donsnotes.app.data.model.Meeting
import com.donsnotes.app.data.model.MeetingStatus
import java.io.File
import java.util.UUID

/**
 * Mock API service for offline testing, mirroring the iOS MockAPIService behavior.
 * Toggle between Mock and Real in DonsNotesApp.kt
 */
class MockApiService {

    private val meetings = mutableListOf(
        Meeting(
            id = UUID.randomUUID().toString(),
            status = MeetingStatus.SENT,
            transcript = "This is a mock transcript of a very productive meeting.",
            summary = "Mock Summary: We discussed building a great app and decided to use Jetpack Compose.",
            attendees = listOf(Attendee(email = "don@example.com", name = "Don")),
            createdAt = java.time.Instant.now().minusSeconds(86400).toString()
        ),
        Meeting(
            id = UUID.randomUUID().toString(),
            status = MeetingStatus.COMPLETED,
            transcript = "Another transcript here.",
            summary = "Discussed the revenue model: Freemium, Lifetime, and Monthly.",
            attendees = listOf(Attendee(email = "jane@example.com", name = "Jane")),
            createdAt = java.time.Instant.now().minusSeconds(3600).toString()
        )
    )

    private val contacts = mutableListOf(
        Attendee(email = "don@example.com", name = "Don"),
        Attendee(email = "jane@example.com", name = "Jane")
    )

    suspend fun uploadMeeting(
        audioFile: File,
        attendees: List<Attendee>,
        organizerName: String?
    ): Meeting {
        kotlinx.coroutines.delay(2000)
        val newMeeting = Meeting(
            id = UUID.randomUUID().toString(),
            status = MeetingStatus.PENDING,
            attendees = attendees,
            organizerName = organizerName,
            createdAt = java.time.Instant.now().toString()
        )
        meetings.add(0, newMeeting)
        return newMeeting
    }

    suspend fun fetchMeetings(): List<Meeting> {
        kotlinx.coroutines.delay(500)
        return meetings.toList()
    }

    suspend fun fetchMeetingDetails(id: String): Meeting {
        kotlinx.coroutines.delay(500)
        val index = meetings.indexOfFirst { it.id == id }
        if (index == -1) throw Exception("Meeting not found")

        val meeting = meetings[index]
        // Simulate status progression
        val updated = when (meeting.status) {
            MeetingStatus.PENDING -> meeting.copy(
                status = MeetingStatus.TRANSCRIBING
            )
            MeetingStatus.TRANSCRIBING -> meeting.copy(
                status = MeetingStatus.SUMMARIZING,
                transcript = "Mock transcript being generated..."
            )
            MeetingStatus.SUMMARIZING -> meeting.copy(
                status = MeetingStatus.COMPLETED,
                transcript = "Full mock transcript.",
                summary = "Final mock summary generated."
            )
            else -> meeting
        }
        meetings[index] = updated
        return updated
    }

    suspend fun sendRecapEmail(id: String) {
        kotlinx.coroutines.delay(1000)
        val index = meetings.indexOfFirst { it.id == id }
        if (index != -1) {
            meetings[index] = meetings[index].copy(status = MeetingStatus.SENT)
        }
    }

    suspend fun fetchContacts(): List<Attendee> {
        kotlinx.coroutines.delay(500)
        return contacts.toList()
    }

    suspend fun saveContact(attendee: Attendee) {
        kotlinx.coroutines.delay(500)
        if (contacts.none { it.email == attendee.email }) {
            contacts.add(attendee)
        }
    }
}
