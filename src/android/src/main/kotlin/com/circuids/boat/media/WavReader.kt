package com.circuids.boat.media

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Minimal RIFF/WAVE reader for uncompressed 16-bit PCM.
 *
 * RIFF is a fully specified, trivial container; MediaExtractor/MediaCodec would
 * add a codec state machine for zero benefit on uncompressed PCM.
 */
class WavReader private constructor(
    val sampleRate: Int,
    val channelCount: Int,
    val bitsPerSample: Int,
    private val dataOffset: Long,
    private val dataLength: Long,
    private val file: RandomAccessFile,
) : AutoCloseable {

    /** Total playable duration in milliseconds. */
    val durationMs: Long
        get() = if (sampleRate <= 0) 0 else dataLength * 1000 / (sampleRate.toLong() * channelCount * (bitsPerSample / 8))

    /**
     * Reads up to [maxBytes] of PCM from [positionBytes] into [dest].
     *
     * @return bytes read, or -1 at end of data.
     */
    fun read(dest: ByteArray, positionBytes: Long, maxBytes: Int): Int {
        if (positionBytes >= dataLength) return -1
        val remaining = dataLength - positionBytes
        val toRead = minOf(maxBytes.toLong(), remaining).toInt()
        file.seek(dataOffset + positionBytes)
        val read = file.read(dest, 0, toRead)
        return if (read <= 0) -1 else read
    }

    override fun close() {
        runCatching { file.close() }
    }

    companion object {
        /** Thrown for any malformed or unsupported WAV input. */
        class WavFormatException(message: String) : Exception(message)

        private const val RIFF = 0x52494646 // "RIFF"
        private const val WAVE = 0x57415645 // "WAVE"
        private const val FMT = 0x666D7420 // "fmt "
        private const val DATA = 0x64617461 // "data"
        private const val FORMAT_PCM = 1

        /**
         * Parses the header of [path].
         *
         * @throws WavFormatException for a non-RIFF container, a missing
         *         `fmt `/`data` chunk, or an unsupported format.
         */
        fun open(path: String): WavReader {
            val file = RandomAccessFile(File(path), "r")
            try {
                val header = ByteArray(12)
                if (file.read(header) != 12) {
                    throw WavFormatException("File too short for a RIFF header")
                }
                val buf = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                if (buf.int != RIFF) throw WavFormatException("Not a RIFF container")
                buf.int // riffSize — unused
                if (buf.int != WAVE) throw WavFormatException("Not a WAVE file")

                var sampleRate = 0
                var channels = 0
                var bits = 0
                var audioFormat = -1
                var dataOffset = -1L
                var dataLength = -1L

                val chunkHeader = ByteArray(8)
                while (file.filePointer < file.length()) {
                    if (file.read(chunkHeader) != 8) break
                    val cb = ByteBuffer.wrap(chunkHeader).order(ByteOrder.LITTLE_ENDIAN)
                    val id = cb.int
                    val size = cb.int.toLong() and 0xFFFFFFFFL
                    val bodyStart = file.filePointer

                    when (id) {
                        FMT -> {
                            if (size < 16) throw WavFormatException("fmt chunk too small")
                            val fmt = ByteArray(16)
                            file.readFully(fmt)
                            val fb = ByteBuffer.wrap(fmt).order(ByteOrder.LITTLE_ENDIAN)
                            audioFormat = fb.short.toInt() and 0xFFFF
                            channels = fb.short.toInt() and 0xFFFF
                            sampleRate = fb.int
                            fb.int // byteRate — unused
                            fb.short // blockAlign — unused
                            bits = fb.short.toInt() and 0xFFFF
                        }
                        DATA -> {
                            dataOffset = bodyStart
                            dataLength = minOf(size, file.length() - bodyStart)
                        }
                    }

                    // Chunks are word-aligned: odd sizes carry a pad byte.
                    val advance = size + (size and 1L)
                    file.seek(bodyStart + advance)
                }

                if (audioFormat == -1) throw WavFormatException("Missing fmt chunk")
                if (dataOffset < 0) throw WavFormatException("Missing data chunk")
                if (audioFormat != FORMAT_PCM) {
                    throw WavFormatException(
                        "Unsupported audioFormat $audioFormat (only PCM=1 is supported)"
                    )
                }
                if (bits != 16) throw WavFormatException("Unsupported bitsPerSample $bits (only 16)")
                if (channels != 1 && channels != 2) {
                    throw WavFormatException("Unsupported channelCount $channels (only 1 or 2)")
                }
                if (sampleRate <= 0) throw WavFormatException("Invalid sampleRate $sampleRate")

                return WavReader(sampleRate, channels, bits, dataOffset, dataLength, file)
            } catch (e: Exception) {
                runCatching { file.close() }
                throw e
            }
        }
    }
}
