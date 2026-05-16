package com.example.flutter_application_1.live2d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class Live2DModelInfoSchemaTest {

    @Test
    fun decodeMotionGroups_acceptsListSchema_forBothModelModes() {
        val cubismPayload = mapOf(
            "Idle" to listOf("idle_01.motion3.json", "idle_02.motion3.json"),
            "TapBody" to listOf("tap_01.motion3.json")
        )
        val fallbackPayload = mapOf(
            "Idle" to listOf("idle_01.motion3.json", "idle_02.motion3.json"),
            "TapBody" to listOf("tap_01.motion3.json")
        )

        val cubismDecoded = Live2DModelInfoDecoder.decodeMotionGroups(cubismPayload)
        val fallbackDecoded = Live2DModelInfoDecoder.decodeMotionGroups(fallbackPayload)

        assertEquals(cubismDecoded, fallbackDecoded)
        assertEquals(2, cubismDecoded["Idle"]?.size)
    }

    @Test
    fun decodeMotionGroups_acceptsLegacyCountSchema_forBackwardCompatibility() {
        val legacyPayload = mapOf(
            "Idle" to 2,
            "TapBody" to 1,
        )

        val decoded = Live2DModelInfoDecoder.decodeMotionGroups(legacyPayload)

        assertEquals(listOf("Idle:0", "Idle:1"), decoded["Idle"])
        assertEquals(listOf("TapBody:0"), decoded["TapBody"])
    }

    @Test
    fun decodeMotionGroups_throwsOnInvalidElementType() {
        val invalidPayload = mapOf(
            "Idle" to listOf("idle_01.motion3.json", 123),
        )

        assertThrows(IllegalArgumentException::class.java) {
            Live2DModelInfoDecoder.decodeMotionGroups(invalidPayload)
        }
    }

    @Test
    fun decodeStringList_throwsOnInvalidExpressionType() {
        assertThrows(IllegalArgumentException::class.java) {
            Live2DModelInfoDecoder.decodeStringList(
                listOf("happy", 1),
                "expressions"
            )
        }
    }
}
