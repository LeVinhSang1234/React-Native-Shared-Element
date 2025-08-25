package com.sharevideo.video

import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

class RCTVideoViewManager : SimpleViewManager<RCTVideoView>() {
    override fun getName() = "RCTVideo"

    override fun createViewInstance(reactContext: ThemedReactContext): RCTVideoView {
        return RCTVideoView(reactContext)
    }

    override fun onDropViewInstance(view: RCTVideoView) {
        super.onDropViewInstance(view)
        view.cleanup()
    }

    @ReactProp(name = "source")
    fun setSource(view: RCTVideoView, value: String?) {
        view.setSource(value)
    }

    @ReactProp(name = "loop", defaultBoolean = false)
    fun setLoop(view: RCTVideoView, value: Boolean) {
        view.setLoop(value)
    }

    @ReactProp(name = "paused", defaultBoolean = false)
    fun setPaused(view: RCTVideoView, value: Boolean) {
        view.setPaused(value)
    }

    @ReactProp(name = "muted", defaultBoolean = false)
    fun setMuted(view: RCTVideoView, value: Boolean) {
        view.setMuted(value)
    }

    @ReactProp(name = "volume")
    fun setVolume(view: RCTVideoView, value: Double) = view.setVolume(value)

    @ReactProp(name = "seek") fun setSeek(view: RCTVideoView, value: Double) = view.setSeek(value)

    @ReactProp(name = "resizeMode")
    fun setResizeMode(view: RCTVideoView, value: String?) = view.setResizeMode(value)

    @ReactProp(name = "enableProgress")
    fun setEnableProgress(view: RCTVideoView, value: Boolean) {
        view.setEnableProgress(value)
    }

    @ReactProp(name = "progressInterval")
    fun setProgressInterval(view: RCTVideoView, ms: Double) {
        view.setProgressInterval(ms)
    }

    @ReactProp(name = "enableOnLoad")
    fun setEnableOnLoad(view: RCTVideoView, value: Boolean) {
        view.setEnableOnLoad(value)
    }

    override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
        mutableMapOf(
            "onLoadStart" to mutableMapOf("registrationName" to "onLoadStart"),
            "onLoad" to mutableMapOf("registrationName" to "onLoad"),
            "onProgress" to mutableMapOf("registrationName" to "onProgress"),
            "onError" to mutableMapOf("registrationName" to "onError"),
            "onBuffering" to mutableMapOf("registrationName" to "onBuffering")
        )
}
