package com.circuids.boat.pipeline

/**
 * Pre-allocated mutable frame reused across pipeline iterations.
 * Zero allocation per frame.
 */
class MutableAudioFrame(val pcm: ByteArray) {
    var sequenceNumber: Long = 0
    var timestampNanos: Long = 0
    var sampleRate: Int = 16000
    var channelCount: Int = 1
    var speechActive: Boolean = false
    var speechConfidence: Float = 0f
    var processingTimeNanos: Long = 0
    var dropped: Boolean = false
    var validBytes: Int = pcm.size

    fun reset() {
        sequenceNumber = 0
        timestampNanos = 0
        speechActive = false
        speechConfidence = 0f
        processingTimeNanos = 0
        dropped = false
        validBytes = pcm.size
    }
}
