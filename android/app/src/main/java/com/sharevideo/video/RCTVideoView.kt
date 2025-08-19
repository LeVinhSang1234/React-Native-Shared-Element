package com.sharevideo.video

import android.content.Context
import android.util.AttributeSet
import android.view.View.MeasureSpec
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * PlayerView + Media3 (không dùng AspectRatioFrameLayout). Resize theo resizeMode bằng:
 * - Nếu width EXACTLY & height !EXACTLY: đo lại khung (measureChildren + setMeasuredDimension).
 * - Nếu khung cố định (EXACTLY cho cả 2 hoặc height EXACTLY): giữ khung, tự layout PlayerView bên
 * trong (contain/cover/stretch).
 *
 * Props: source, paused, loop, muted, volume(0..1), seek(giây),
 * resizeMode("contain"|"cover"|"stretch"|"fill") Event: onLoad { width, height, duration }
 */
class RCTVideoView : FrameLayout {

    private lateinit var playerView: PlayerView
    private var player: ExoPlayer? = null

    private var currentSource: String? = null
    private var pendingSource: String? = null

    private var loopFlag = false
    private var mutedFlag = false
    private var rememberedVolume = 1f

    private var externallyPaused = false
    private var hostResumed = true

    private var pendingSeekMs: Long? = null
    private var pendingVolume: Float? = null

    private var videoW = 0
    private var videoH = 0
    private var didEmitOnLoad = false

    private var resizeModeStr: String = "contain" // contain | cover | stretch | fill

    // lưu specs gần nhất để quyết định ép aspect
    private var lastWidthPx: Int = 0
    private var lastHeightPx: Int = 0
    private var lastWidthMode: Int = MeasureSpec.UNSPECIFIED
    private var lastHeightMode: Int = MeasureSpec.UNSPECIFIED
    private var savedSpecsValid = false

    private val trc: ThemedReactContext?
        get() = context as? ThemedReactContext
    private val lifecycle =
            object : LifecycleEventListener {
                override fun onHostResume() {
                    hostResumed = true
                    updatePlayState()
                }
                override fun onHostPause() {
                    hostResumed = false
                    updatePlayState()
                }
                override fun onHostDestroy() {
                    /* release ở cleanup() */
                }
            }

    constructor(context: Context) : super(context) {
        configureComponent()
    }
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        configureComponent()
    }
    constructor(
            context: Context,
            attrs: AttributeSet?,
            defStyleAttr: Int
    ) : super(context, attrs, defStyleAttr) {
        configureComponent()
    }

    private fun configureComponent() {
        clipChildren = true
        playerView = PlayerView(context, null, 0).apply { useController = false }
        addView(playerView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        player =
                buildPlayer().also { p ->
                    playerView.player = p
                    applyLoop(p)
                    applyMuted(p)
                    pendingVolume?.let {
                        applyVolume(p, it)
                        pendingVolume = null
                    }

                    p.addListener(
                            object : Player.Listener {
                                override fun onVideoSizeChanged(size: VideoSize) {
                                    val w = size.width
                                    val h =
                                            (size.height * size.pixelWidthHeightRatio)
                                                    .roundToInt()
                                                    .coerceAtLeast(1)
                                    if (w > 0 && h > 0) {
                                        videoW = w
                                        videoH = h
                                        applyAspectNow()
                                    }
                                    maybeEmitOnLoad()
                                }
                                override fun onPlaybackStateChanged(state: Int) {
                                    if (state == Player.STATE_ENDED && loopFlag) {
                                        p.seekTo(0)
                                        p.playWhenReady = true
                                    }
                                    if (state == Player.STATE_READY) {
                                        maybeEmitOnLoad()
                                    }
                                }
                                override fun onPlayerError(error: PlaybackException) {
                                    // no-op
                                }
                            }
                    )
                }

        trc?.addLifecycleEventListener(lifecycle)
    }

    private fun buildPlayer(): ExoPlayer {
        val ok = HttpStack.get(context) // OkHttp client có cache 1 ngày
        val upstream = OkHttpDataSource.Factory(ok)
        return ExoPlayer.Builder(context)
                .setMediaSourceFactory(DefaultMediaSourceFactory(upstream))
                .build()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        playerView.player = player
        pendingSource?.let { url ->
            if (url != currentSource) loadSource(url)
            pendingSource = null
        }
        if (videoW > 0 && videoH > 0) applyAspectNow()
        updatePlayState()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        playerView.player = null
    }

    fun cleanup() {
        trc?.removeLifecycleEventListener(lifecycle)
        playerView.player = null
        player?.release()
        player = null
        currentSource = null
        pendingSource = null
        pendingSeekMs = null
        pendingVolume = null
        videoW = 0
        videoH = 0
        didEmitOnLoad = false
        savedSpecsValid = false
    }

    // ===== Props từ RN =====

    fun setSource(url: String?) {
        if (url.isNullOrBlank()) return
        val p = player
        if (p == null) {
            pendingSource = url
            return
        }
        if (url == currentSource) return
        loadSource(url)
    }

    fun setPaused(paused: Boolean) {
        externallyPaused = paused
        updatePlayState()
    }

    fun setLoop(loop: Boolean) {
        loopFlag = loop
        player?.let { applyLoop(it) }
        if (loop && player?.playbackState == Player.STATE_ENDED) {
            player?.seekTo(0)
            player?.playWhenReady = true
        }
    }

    fun setMuted(muted: Boolean) {
        mutedFlag = muted
        player?.let { applyMuted(it) }
    }

    fun setVolume(vol: Double) {
        val v = vol.toFloat().coerceIn(0f, 1f)
        val p = player
        if (p == null) {
            pendingVolume = v
            return
        }
        rememberedVolume = v
        if (!mutedFlag) applyVolume(p, v)
    }

    fun setSeek(seconds: Double) {
        val ms = max(0L, (seconds * 1000.0).toLong())
        val p = player
        if (p == null || p.mediaItemCount == 0) {
            pendingSeekMs = ms
            return
        }
        p.seekTo(ms)
    }

    fun setResizeMode(mode: String?) {
        resizeModeStr = (mode ?: "contain").lowercase().trim()
        applyAspectNow()
    }

    // ===== Helpers =====

    private fun updatePlayState() {
        player?.playWhenReady = (hostResumed && !externallyPaused)
    }

    private fun applyLoop(p: ExoPlayer) {
        p.repeatMode = if (loopFlag) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    private fun applyMuted(p: ExoPlayer) {
        if (mutedFlag) {
            if (p.volume > 0f) rememberedVolume = p.volume
            p.volume = 0f
        } else {
            applyVolume(p, rememberedVolume)
        }
    }

    private fun applyVolume(p: ExoPlayer, v: Float) {
        p.volume = v.coerceIn(0f, 1f)
    }

    private fun loadSource(url: String) {
        val p = player ?: return
        currentSource = url
        didEmitOnLoad = false
        videoW = 0
        videoH = 0

        p.setMediaItem(MediaItem.fromUri(url))
        pendingSeekMs?.let {
            p.seekTo(it)
            pendingSeekMs = null
        }

        post {
            p.prepare()
            p.playWhenReady = (hostResumed && !externallyPaused)
            applyLoop(p)
            applyMuted(p)
        }
    }

    // ----- Events -----

    private class OnLoadEvent(
            viewId: Int,
            private val w: Int,
            private val h: Int,
            private val durSec: Double?
    ) : Event<OnLoadEvent>(viewId) {
        override fun getEventName() = "onLoad"
        override fun canCoalesce() = false
        override fun dispatch(rctEventEmitter: RCTEventEmitter) {
            val map =
                    Arguments.createMap().apply {
                        putInt("width", w)
                        putInt("height", h)
                        durSec?.let { putDouble("duration", it) }
                    }
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    private fun maybeEmitOnLoad() {
        val p = player ?: return
        if (didEmitOnLoad) return
        if (p.playbackState != Player.STATE_READY) return
        if (videoW <= 0 || videoH <= 0) return

        // bảo đảm aspect đã áp dụng trước khi báo JS
        applyAspectNow()

        post {
            if (didEmitOnLoad) return@post
            if (!ViewCompat.isAttachedToWindow(this)) return@post
            val reactCtx = context as? ReactContext ?: return@post
            if (!reactCtx.hasActiveCatalystInstance()) return@post

            val viewId = id.takeIf { it > 0 } ?: return@post
            val dispatcher =
                    UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId) ?: return@post
            val durSec = if (p.duration > 0) p.duration / 1000.0 else null

            dispatcher.dispatchEvent(OnLoadEvent(viewId, videoW, videoH, durSec))
            didEmitOnLoad = true
        }
    }

    // ===== Aspect handling =====

    // Gọi ở: onVideoSizeChanged, setResizeMode, onAttached, maybeEmitOnLoad
    private fun applyAspectNow() {
        if (videoW <= 0 || videoH <= 0) return

        // 1) stretch/fill: kéo giãn đầy khung, bỏ tỉ lệ
        if (resizeModeStr == "stretch" || resizeModeStr == "fill") {
            // ép StyledPlayerView fill nội bộ (nếu có AspectRatioFrameLayout bên trong)
            try { playerView.resizeMode = 3 /* RESIZE_MODE_FILL */ } catch (_: Throwable) {}
            val w = when {
                measuredWidth > 0 -> measuredWidth
                lastWidthPx > 0   -> lastWidthPx
                else              -> width
            }
            val h = when {
                measuredHeight > 0 -> measuredHeight
                lastHeightPx > 0   -> lastHeightPx
                else               -> height
            }
            if (w <= 0 || h <= 0) return

            playerView.measure(
                MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY)
            )
            playerView.layout(0, 0, w, h)
            invalidate()
            return
        }

        // 2) Auto-height cho contain/cover (không áp cho center)
        if (
            savedSpecsValid &&
            lastWidthMode == MeasureSpec.EXACTLY &&
            lastHeightMode != MeasureSpec.EXACTLY &&
            lastWidthPx > 0 &&
            resizeModeStr != "center"
        ) {
            val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
            val wSpec = MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY)
            val hSpec = MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
            measureChildren(wSpec, hSpec)
            setMeasuredDimension(lastWidthPx, targetH)
            getChildAt(0)?.layout(0, 0, lastWidthPx, targetH)
            invalidate()
            return
        }

        // 3) Khung cố định → layout PlayerView theo resizeMode (contain/cover/center)
        val w = if (measuredWidth > 0) measuredWidth else width
        val h = if (measuredHeight > 0) measuredHeight else height
        if (w <= 0 || h <= 0) return

        val rect = computeChildRect(w, h)
        playerView.measure(
            MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
        invalidate()
    }

    private fun keepAspect(): Boolean = resizeModeStr != "stretch" && resizeModeStr != "fill"

    // Tính rect con theo resizeMode bên trong khung cố định w x h
    private fun computeChildRect(w: Int, h: Int): android.graphics.Rect {
        val rect = android.graphics.Rect(0, 0, w, h)
        if (videoW <= 0 || videoH <= 0) return rect

        return when (resizeModeStr) {
            // kéo giãn toàn khung, bỏ tỉ lệ
            "stretch", "fill" -> rect

            // không scale, chỉ canh giữa; nếu lớn hơn khung thì bị cắt (clip)
            "center" -> {
                val targetW = videoW.coerceAtMost(w)
                val targetH = videoH.coerceAtMost(h)
                val left = (w - targetW) / 2
                val top  = (h - targetH) / 2
                rect.set(left, top, left + targetW, top + targetH)
                rect
            }

            // phủ kín, giữ tỉ lệ (crop)
            "cover" -> {
                val scale = maxOf(w / videoW.toFloat(), h / videoH.toFloat())
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (w - targetW) / 2
                val top  = (h - targetH) / 2
                rect.set(left, top, left + targetW, top + targetH)
                rect
            }

            // mặc định: contain, giữ tỉ lệ, toàn bộ nằm trong khung
            else -> {
                val scale = minOf(w / videoW.toFloat(), h / videoH.toFloat())
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (w - targetW) / 2
                val top  = (h - targetH) / 2
                rect.set(left, top, left + targetW, top + targetH)
                rect
            }
        }
    }

    // Lưu specs và xử lý nhanh case width EXACTLY & height !EXACTLY ngay trong measure
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        lastWidthPx = MeasureSpec.getSize(widthMeasureSpec)
        lastHeightPx = MeasureSpec.getSize(heightMeasureSpec)
        lastWidthMode = MeasureSpec.getMode(widthMeasureSpec)
        lastHeightMode = MeasureSpec.getMode(heightMeasureSpec)
        savedSpecsValid = true

        if (keepAspect() && videoW > 0 && videoH > 0) {
            if (lastWidthMode == MeasureSpec.EXACTLY && lastHeightMode != MeasureSpec.EXACTLY) {
                val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
                val wSpec = MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY)
                val hSpec = MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
                measureChildren(wSpec, hSpec)
                setMeasuredDimension(lastWidthPx, targetH)
                return
            }
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    // Với khung cố định: đặt PlayerView theo resizeMode mỗi lần layout
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val w = right - left
        val h = bottom - top
        if (w <= 0 || h <= 0) return

        val rect = computeChildRect(w, h)
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }
}
