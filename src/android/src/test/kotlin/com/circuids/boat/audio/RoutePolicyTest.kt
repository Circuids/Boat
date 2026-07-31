package com.circuids.boat.audio

import kotlin.test.Test
import kotlin.test.assertEquals

internal class RoutePolicyTest {

    @Test
    fun externalDeviceAlwaysWins() {
        val policy = RoutePolicy(speakerMode = true, preferredRoute = BoatAudioRoute.SPEAKER)
        assertEquals(BoatAudioRoute.BLUETOOTH, policy.selectRoute(BoatAudioRoute.BLUETOOTH))
        assertEquals(BoatAudioRoute.WIRED_HEADSET, policy.selectRoute(BoatAudioRoute.WIRED_HEADSET))
        assertEquals(BoatAudioRoute.USB, policy.selectRoute(BoatAudioRoute.USB))
    }

    @Test
    fun speakerModeTrueFallsBackToSpeaker() {
        val policy = RoutePolicy(speakerMode = true, preferredRoute = BoatAudioRoute.EARPIECE)
        assertEquals(BoatAudioRoute.SPEAKER, policy.selectRoute(null))
    }

    @Test
    fun speakerModeFalseFallsBackToPreferredRoute() {
        val policy = RoutePolicy(speakerMode = false, preferredRoute = BoatAudioRoute.EARPIECE)
        assertEquals(BoatAudioRoute.EARPIECE, policy.selectRoute(null))
    }

    @Test
    fun externalOverridesEvenWhenSpeakerModeFalse() {
        val policy = RoutePolicy(speakerMode = false, preferredRoute = BoatAudioRoute.EARPIECE)
        assertEquals(BoatAudioRoute.BLUETOOTH, policy.selectRoute(BoatAudioRoute.BLUETOOTH))
    }

    @Test
    fun defaultConfigSelectsSpeakerWithNoExternal() {
        val policy = RoutePolicy(speakerMode = true, preferredRoute = BoatAudioRoute.SPEAKER)
        assertEquals(BoatAudioRoute.SPEAKER, policy.selectRoute(null))
    }
}
