package com.circuids.boat.media

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

internal class WavReaderTest {

    private val tempFiles = mutableListOf<File>()

    @AfterTest
    fun tearDown() {
        tempFiles.forEach { it.delete() }
        tempFiles.clear()
    }

    // ── Helpers ──

    private fun writeWav(
        sampleRate: Int = 16000,
        channels: Int = 1,
        bits: Int = 16,
        audioFormat: Int = 1,
        pcmBytes: Int = 320,
        extraChunk: Boolean = false,
        oddDataSize: Boolean = false,
    ): String {
        val dataSize = if (oddDataSize) pcmBytes or 1 else pcmBytes
        val fmtSize = 16
        val extraSize = if (extraChunk) 8 + 4 else 0
        val riffSize = 4 + (8 + fmtSize) + extraSize + (8 + dataSize) + (dataSize and 1)

        val buf = ByteBuffer.allocate(8 + riffSize).order(ByteOrder.LITTLE_ENDIAN)
        buf.putInt(0x52494646) // RIFF
        buf.putInt(riffSize)
        buf.putInt(0x57415645) // WAVE

        buf.putInt(0x666D7420) // fmt
        buf.putInt(fmtSize)
        buf.putShort(audioFormat.toShort())
        buf.putShort(channels.toShort())
        buf.putInt(sampleRate)
        buf.putInt(sampleRate * channels * bits / 8) // byteRate
        buf.putShort((channels * bits / 8).toShort()) // blockAlign
        buf.putShort(bits.toShort())

        if (extraChunk) {
            buf.putInt(0x4C495354) // "LIST" — unknown chunk to be skipped
            buf.putInt(4)
            buf.putInt(0)
        }

        buf.putInt(0x64617461) // data
        buf.putInt(dataSize)
        repeat(dataSize) { buf.put(0) }
        if (dataSize and 1 == 1) buf.put(0) // RIFF pad byte

        val file = File.createTempFile("boat-wav-", ".wav")
        file.writeBytes(buf.array())
        tempFiles.add(file)
        return file.absolutePath
    }

    // ── Valid input ──

    @Test
    fun readsMono16Bit() {
        val reader = WavReader.open(writeWav(channels = 1, sampleRate = 16000))
        reader.use {
            assertEquals(16000, it.sampleRate)
            assertEquals(1, it.channelCount)
            assertEquals(16, it.bitsPerSample)
        }
    }

    @Test
    fun readsStereo16Bit() {
        val reader = WavReader.open(writeWav(channels = 2, sampleRate = 48000))
        reader.use {
            assertEquals(48000, it.sampleRate)
            assertEquals(2, it.channelCount)
        }
    }

    @Test
    fun computesDuration() {
        // 16000 Hz mono 16-bit, 320 bytes = 160 samples = 10 ms
        val reader = WavReader.open(writeWav(sampleRate = 16000, channels = 1, pcmBytes = 320))
        reader.use { assertEquals(10L, it.durationMs) }
    }

    @Test
    fun skipsUnknownChunks() {
        val reader = WavReader.open(writeWav(extraChunk = true))
        reader.use { assertEquals(16000, it.sampleRate) }
    }

    @Test
    fun handlesOddSizedDataWithPadByte() {
        val reader = WavReader.open(writeWav(pcmBytes = 320, oddDataSize = true))
        reader.use { assertTrue(it.durationMs >= 0) }
    }

    @Test
    fun readsPcmPayload() {
        val reader = WavReader.open(writeWav(pcmBytes = 320))
        reader.use {
            val dest = ByteArray(320)
            val read = it.read(dest, 0, 320)
            assertEquals(320, read)
        }
    }

    @Test
    fun readReturnsMinusOneAtEnd() {
        val reader = WavReader.open(writeWav(pcmBytes = 320))
        reader.use {
            val dest = ByteArray(320)
            assertEquals(-1, it.read(dest, 320, 320))
        }
    }

    // ── Rejections ──

    @Test
    fun rejectsNonRiffContainer() {
        val file = File.createTempFile("boat-bad-", ".wav")
        file.writeBytes(ByteArray(64))
        tempFiles.add(file)
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(file.absolutePath)
        }
    }

    @Test
    fun rejectsFloatFormat() {
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(writeWav(audioFormat = 3))
        }
    }

    @Test
    fun rejectsExtensibleFormat() {
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(writeWav(audioFormat = 0xFFFE))
        }
    }

    @Test
    fun rejects8Bit() {
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(writeWav(bits = 8))
        }
    }

    @Test
    fun rejectsUnsupportedChannelCount() {
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(writeWav(channels = 6))
        }
    }

    @Test
    fun rejectsTruncatedHeader() {
        val file = File.createTempFile("boat-short-", ".wav")
        file.writeBytes(ByteArray(4))
        tempFiles.add(file)
        assertFailsWith<WavReader.Companion.WavFormatException> {
            WavReader.open(file.absolutePath)
        }
    }
}
