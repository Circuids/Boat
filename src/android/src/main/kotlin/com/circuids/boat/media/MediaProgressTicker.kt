package com.circuids.boat.media

import android.os.Handler
import android.os.Looper

/**
 * Owns the ~200 ms progress timer for the media bus.
 *
 * A single owner exists so the timer is always cancelled with the engine that
 * started it — no orphaned callbacks after stop/pause/release.
 */
class MediaProgressTicker(
    private val intervalMs: Long = 200L,
    private val onTick: () -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val runnable = object : Runnable {
        override fun run() {
            onTick()
            handler.postDelayed(this, intervalMs)
        }
    }

    private var running = false

    fun start() {
        if (running) return
        running = true
        handler.postDelayed(runnable, intervalMs)
    }

    fun stop() {
        if (!running) return
        running = false
        handler.removeCallbacks(runnable)
    }
}
