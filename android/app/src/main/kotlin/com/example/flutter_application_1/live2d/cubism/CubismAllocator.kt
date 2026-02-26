package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.nio.ByteBuffer

/**
 * Cubism SDK Memory Allocator
 * 
 * 
 */
class CubismAllocator {
    
    companion object {
        private const val TAG = "CubismAllocator"
    }
    
    /**
     */
    fun allocate(size: Int): ByteBuffer {
        return try {
            ByteBuffer.allocateDirect(size)
        } catch (e: OutOfMemoryError) {
            Live2DLogger.e("$TAG: Failed to allocate $size bytes", e)
            throw e
        }
    }
    
    /**
     */
    fun deallocate(buffer: ByteBuffer?) {
        // Direct buffers are automatically garbage collected
        // No explicit deallocation needed
    }
    
    /**
     */
    fun allocateAligned(size: Int, alignment: Int): ByteBuffer {
        return try {
            // Allocate extra space to ensure alignment
            ByteBuffer.allocateDirect(size + alignment)
        } catch (e: OutOfMemoryError) {
            Live2DLogger.e("$TAG: Failed to allocate aligned $size bytes", e)
            throw e
        }
    }
    
    /**
     */
    fun deallocateAligned(buffer: ByteBuffer?) {
        // Direct buffers are automatically garbage collected
    }
}
