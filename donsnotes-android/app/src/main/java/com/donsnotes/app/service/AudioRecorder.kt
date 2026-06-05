package com.donsnotes.app.service

import android.content.Context
import android.media.MediaRecorder
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class AudioRecorder(private val context: Context) {

    private var mediaRecorder: MediaRecorder? = null
    var isRecording: Boolean = false
        private set
    var outputFile: File? = null
        private set

    suspend fun startRecording(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val fileName = "recording_${System.currentTimeMillis()}.m4a"
            val outputDir = context.cacheDir
            val file = File(outputDir, fileName)
            outputFile = file

            mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioChannels(1)
                setAudioEncodingBitRate(128000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            isRecording = true
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun stopRecording(): Result<File> = withContext(Dispatchers.IO) {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false

            val file = outputFile
            if (file != null && file.exists()) {
                Result.success(file)
            } else {
                Result.failure(Exception("Recording file not found"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun cancelRecording() {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
        } catch (_: Exception) {}
        mediaRecorder = null
        isRecording = false
        outputFile?.delete()
        outputFile = null
    }
}
