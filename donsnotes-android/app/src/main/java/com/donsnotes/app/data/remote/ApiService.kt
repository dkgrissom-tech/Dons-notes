package com.donsnotes.app.data.remote

import com.donsnotes.app.data.model.*
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.*

interface ApiService {
    // Auth
    @POST("v1/auth/login")
    @Headers("Content-Type: application/x-www-form-urlencoded")
    suspend fun login(
        @Body credentials: AuthRequest
    ): AuthResponse

    @POST("v1/auth/signup")
    suspend fun signUp(
        @Body request: SignUpRequest
    ): UserProfile

    // Meetings
    @Multipart
    @POST("v1/meetings/upload")
    suspend fun uploadMeeting(
        @Part file: MultipartBody.Part,
        @Part("attendees") attendees: RequestBody,
        @Part("organizer_name") organizerName: RequestBody? = null
    ): Meeting

    @GET("v1/meetings")
    suspend fun listMeetings(): List<Meeting>

    @GET("v1/meetings/{meetingId}")
    suspend fun getMeeting(
        @Path("meetingId") meetingId: String
    ): Meeting

    @POST("v1/meetings/{meetingId}/send")
    suspend fun sendRecapEmail(
        @Path("meetingId") meetingId: String
    ): Map<String, String>

    // Contacts
    @GET("v1/contacts")
    suspend fun listContacts(): List<Attendee>

    @POST("v1/contacts")
    suspend fun createContact(
        @Body contact: Attendee
    ): Attendee
}
