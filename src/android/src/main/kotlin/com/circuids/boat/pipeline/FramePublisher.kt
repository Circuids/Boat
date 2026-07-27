package com.circuids.boat.pipeline

import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Serializes frames and delivers via EventChannel.
 * Only component that touches Flutter platform channels.
 */
class FramePublisher(private val eventSink: () -> EventChannel.EventSink?) {

    // Wire format: seq(int64) + tsNanos(int64) + sampleRate(int32) + channelCount(int32) + pcm = 24-byte header
    private var serializationBuffer = ByteBuffer.allocate(24 + 6400)

    fun publish(frame: MutableAudioFrame) {
        val sink = eventSink() ?: return
        val totalSize = 24 + frame.validBytes
        if (serializationBuffer.capacity() < totalSize) {
            serializationBuffer = ByteBuffer.allocate(totalSize)
        }
        serializationBuffer.clear()
        serializationBuffer.order(ByteOrder.LITTLE_ENDIAN)
        serializationBuffer.putLong(frame.sequenceNumber)
        serializationBuffer.putLong(frame.timestampNanos)
        serializationBuffer.putInt(frame.sampleRate)
        serializationBuffer.putInt(frame.channelCount)
        serializationBuffer.put(frame.pcm, 0, frame.validBytes)

        val bytes = ByteArray(totalSize)
        serializationBuffer.flip()
        serializationBuffer.get(bytes)
        sink.success(bytes)
    }

    fun emitWarning(code: String, message: String) {
        val sink = eventSink() ?: return
        sink.success(mapOf("type" to "warning", "code" to code, "message" to message))
    }

    fun emitStateChange(previous: String, current: String) {
        val sink = eventSink() ?: return
        sink.success(mapOf("type" to "stateChanged", "previous" to previous, "current" to current))
    }

    fun emitRouteChanged(previous: String, current: String) {
        val sink = eventSink() ?: return
        sink.success(mapOf("type" to "routeChanged", "previous" to previous, "current" to current))
    }
}
