package com.circuids.boat.media

/**
 * Process-wide owner of the OS audio session.
 *
 * The session is a singleton OS resource, so exactly one bus may own it at a
 * time. Voice always wins: [acquireVoice] preempts media, while [acquireMedia]
 * refuses when voice holds it. Media never preempts voice — a UI cue must never
 * interrupt a conversation.
 *
 * Holds no audio resources, only the ownership enum and the media-stop callback.
 */
object MediaSessionArbiter {

    enum class Owner { NONE, VOICE, MEDIA }

    @Volatile
    var owner: Owner = Owner.NONE
        private set

    /**
     * Invoked synchronously by [acquireVoice] when media currently owns the
     * session. Must stop media playback and return only once the output has
     * stopped writing, so voice never starts while media is still draining.
     */
    @Volatile
    var onMediaStop: (() -> Unit)? = null

    /**
     * Acquires the session for voice. Always succeeds; preempts media first.
     */
    @Synchronized
    fun acquireVoice() {
        if (owner == Owner.MEDIA) {
            onMediaStop?.invoke()
        }
        owner = Owner.VOICE
    }

    /**
     * Acquires the session for media.
     *
     * @return false when voice owns the session — the caller must surface
     *         `MEDIA_BUSY` rather than proceeding.
     */
    @Synchronized
    fun acquireMedia(): Boolean {
        if (owner == Owner.VOICE) return false
        owner = Owner.MEDIA
        return true
    }

    /** Releases the session if [expected] is the current owner. */
    @Synchronized
    fun release(expected: Owner) {
        if (owner == expected) owner = Owner.NONE
    }

    /** Test-only reset. */
    @Synchronized
    internal fun resetForTest() {
        owner = Owner.NONE
        onMediaStop = null
    }
}
