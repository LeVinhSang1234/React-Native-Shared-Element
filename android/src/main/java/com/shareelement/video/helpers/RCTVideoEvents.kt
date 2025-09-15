package com.shareelement.video.helpers

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter

class OnLoadStartEvent(
        viewId: Int,
        private val durationSec: Double,
        private val playableDurationSec: Double,
        private val widthPx: Int,
        private val heightPx: Int
) : Event<OnLoadStartEvent>(viewId) {
    override fun getEventName() = "onLoadStart"
    override fun canCoalesce() = false
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
                Arguments.createMap().apply {
                    putDouble("duration", durationSec)
                    putDouble("playableDuration", playableDurationSec)
                    putDouble("width", widthPx.toDouble())
                    putDouble("height", heightPx.toDouble())
                }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnProgressEvent(
        viewId: Int,
        private val positionSec: Double,
        private val durationSec: Double?,
        private val playableDurationSec: Double
) : Event<OnProgressEvent>(viewId) {
    override fun getEventName() = "onProgress"
    override fun canCoalesce() = true
    override fun getCoalescingKey(): Short = (positionSec * 10).toInt().toShort()
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
                Arguments.createMap().apply {
                    putDouble("currentTime", positionSec)
                    durationSec?.let { putDouble("duration", it) }
                    putDouble("playableDuration", playableDurationSec)
                }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnLoadEvent(
        viewId: Int,
        private val loadedDurationSec: Double,
        private val durationSec: Double
) : Event<OnLoadEvent>(viewId) {
    override fun getEventName() = "onLoad"
    override fun canCoalesce() = false
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map =
                Arguments.createMap().apply {
                    putDouble("loadedDuration", loadedDurationSec)
                    putDouble("duration", durationSec)
                }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnBufferingEvent(viewId: Int, private val isBuffering: Boolean) :
        Event<OnBufferingEvent>(viewId) {
    override fun getEventName() = "onBuffering"
    override fun canCoalesce() = false
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap().apply { putBoolean("isBuffering", isBuffering) }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnEndEvent(viewId: Int) : Event<OnEndEvent>(viewId) {
    override fun getEventName() = "onEnd"
    override fun canCoalesce() = false
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap()
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}

class OnErrorEvent(
    viewId: Int,
    private val message: String,
    private val code: String?,
    private val track: String?
) : Event<OnErrorEvent>(viewId) {
    override fun getEventName() = "onError"
    override fun canCoalesce() = false
    @Deprecated("Prefer to override getEventData instead")
    override fun dispatch(rctEventEmitter: RCTEventEmitter) {
        val map = Arguments.createMap().apply {
            putString("message", message)
            code?.let { putString("code", it) }
            track?.let { putString("track", it) }
        }
        rctEventEmitter.receiveEvent(viewTag, eventName, map)
    }
}