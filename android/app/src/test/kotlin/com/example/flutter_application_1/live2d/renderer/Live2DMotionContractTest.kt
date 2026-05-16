package com.example.flutter_application_1.live2d.renderer

import org.junit.Assert.assertEquals
import org.junit.Test

class Live2DMotionContractTest {

    @Test
    fun `typed dispatch preserves sdk group and index`() {
        val dispatch = Live2DGLRenderer.Companion.buildMotionDispatch("Idle", 3)

        assertEquals("Idle", dispatch.group)
        assertEquals(3, dispatch.index)
        assertEquals("Idle:3", dispatch.fallbackMotionName)
    }

    @Test
    fun `legacy separators parse to equivalent typed dispatch`() {
        val underscoreDispatch = Live2DGLRenderer.Companion.parseMotionName("TapBody_2")
        val colonDispatch = Live2DGLRenderer.Companion.parseMotionName("TapBody:2")

        assertEquals(underscoreDispatch.group, colonDispatch.group)
        assertEquals(underscoreDispatch.index, colonDispatch.index)
        assertEquals("TapBody", colonDispatch.group)
        assertEquals(2, colonDispatch.index)
    }
}
