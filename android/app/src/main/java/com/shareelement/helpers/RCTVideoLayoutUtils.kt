package com.shareelement.helpers

import android.graphics.Rect
import kotlin.math.max
import kotlin.math.roundToInt

object RCTVideoLayoutUtils {

    fun keepAspect(resizeModeStr: String): Boolean {
        val mode = resizeModeStr.lowercase()
        return mode != "stretch" && mode != "fill"
    }

    fun computeChildRect(
            containerW: Int,
            containerH: Int,
            videoW: Int,
            videoH: Int,
            resizeModeStr: String
    ): Rect {
        val rect = Rect(0, 0, containerW, containerH)
        if (videoW <= 0 || videoH <= 0) return rect

        return when (resizeModeStr.lowercase()) {
            "stretch", "fill" -> rect
            "center" -> {
                val targetW = videoW.coerceAtMost(containerW)
                val targetH = videoH.coerceAtMost(containerH)
                val left = (containerW - targetW) / 2
                val top = (containerH - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }
            "cover" -> {
                val scale = max(containerW / videoW.toFloat(), containerH / videoH.toFloat())
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (containerW - targetW) / 2
                val top = (containerH - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }
            else -> {
                val scale =
                        kotlin.math.min(
                                containerW / videoW.toFloat(),
                                containerH / videoH.toFloat()
                        )
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (containerW - targetW) / 2
                val top = (containerH - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }
        }
    }
}
