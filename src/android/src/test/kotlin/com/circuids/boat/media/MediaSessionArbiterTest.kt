package com.circuids.boat.media

import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class MediaSessionArbiterTest {

    @AfterTest
    fun tearDown() {
        MediaSessionArbiter.resetForTest()
    }

    @Test
    fun startsUnowned() {
        assertEquals(MediaSessionArbiter.Owner.NONE, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireMediaSucceedsWhenUnowned() {
        assertTrue(MediaSessionArbiter.acquireMedia())
        assertEquals(MediaSessionArbiter.Owner.MEDIA, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireMediaIsIdempotentWhileMediaOwns() {
        assertTrue(MediaSessionArbiter.acquireMedia())
        assertTrue(MediaSessionArbiter.acquireMedia())
        assertEquals(MediaSessionArbiter.Owner.MEDIA, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireMediaRefusedWhenVoiceOwns() {
        MediaSessionArbiter.acquireVoice()
        assertFalse(MediaSessionArbiter.acquireMedia())
        assertEquals(MediaSessionArbiter.Owner.VOICE, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireVoiceAlwaysSucceeds() {
        MediaSessionArbiter.acquireVoice()
        MediaSessionArbiter.acquireVoice()
        assertEquals(MediaSessionArbiter.Owner.VOICE, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireVoicePreemptsMediaAndInvokesStopCallback() {
        var stopped = false
        MediaSessionArbiter.onMediaStop = { stopped = true }
        MediaSessionArbiter.acquireMedia()

        MediaSessionArbiter.acquireVoice()

        assertTrue(stopped, "media-stop callback must fire before acquireVoice returns")
        assertEquals(MediaSessionArbiter.Owner.VOICE, MediaSessionArbiter.owner)
    }

    @Test
    fun acquireVoiceDoesNotInvokeCallbackWhenMediaIdle() {
        var stopped = false
        MediaSessionArbiter.onMediaStop = { stopped = true }

        MediaSessionArbiter.acquireVoice()

        assertFalse(stopped)
    }

    @Test
    fun releaseClearsMatchingOwner() {
        MediaSessionArbiter.acquireMedia()
        MediaSessionArbiter.release(MediaSessionArbiter.Owner.MEDIA)
        assertEquals(MediaSessionArbiter.Owner.NONE, MediaSessionArbiter.owner)
    }

    @Test
    fun releaseIgnoresNonMatchingOwner() {
        MediaSessionArbiter.acquireVoice()
        MediaSessionArbiter.release(MediaSessionArbiter.Owner.MEDIA)
        assertEquals(MediaSessionArbiter.Owner.VOICE, MediaSessionArbiter.owner)
    }

    @Test
    fun mediaCanAcquireAfterVoiceReleases() {
        MediaSessionArbiter.acquireVoice()
        MediaSessionArbiter.release(MediaSessionArbiter.Owner.VOICE)
        assertTrue(MediaSessionArbiter.acquireMedia())
    }
}
