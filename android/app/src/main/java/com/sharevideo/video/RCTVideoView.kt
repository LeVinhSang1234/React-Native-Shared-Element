package com.sharevideo.video

import android.content.Context
import android.graphics.Rect
import android.util.AttributeSet
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.core.view.ViewCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.sharevideo.helpers.OnBufferingEvent
import com.sharevideo.helpers.OnEndEvent
import com.sharevideo.helpers.OnErrorEvent
import com.sharevideo.helpers.OnLoadStartEvent
import com.sharevideo.helpers.RCTVideoErrorUtils
import com.sharevideo.helpers.RCTVideoLayoutUtils
import com.sharevideo.helpers.RCTVideoTickers
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * RCTVideoView: ExoPlayer + PlayerView Props: source, paused, loop, muted, volume, seek,
 * resizeMode,
 * ```
 *        enableProgress, progressInterval, enableOnLoad, headerHeight, shareTagElement
 * ```
 * Events: onLoadStart, onProgress, onLoad, onBuffering, onEnd, onError
 */
class RCTVideoView : FrameLayout {

    // Player & view
    private lateinit var playerView: PlayerView
    private var player: ExoPlayer? = null

    // Source state
    private var currentSource: String? = null
    private var pendingSource: String? = null

    // Playback flags
    private var isLooping = false
    private var isMuted = false
    private var rememberedVolume = 1f
    private var externallyPaused = false
    private var isHostResumed = true

    // Pending controls
    private var pendingSeekMs: Long? = null
    private var pendingVolume: Float? = null

    // Video intrinsic size
    private var videoW = 0
    private var videoH = 0

    // Resize / measure cache
    private var resizeModeStr: String = "contain"
    private var lastWidthPx: Int = 0
    private var lastHeightPx: Int = 0
    private var lastWidthMode: Int = MeasureSpec.UNSPECIFIED
    private var lastHeightMode: Int = MeasureSpec.UNSPECIFIED
    private var savedSpecsValid = false

    // Tickers
    private var progressIntervalMs = 250L
    private var isProgressEnabled = false
    private var isOnLoadEnabled = false
    private var lastIsBuffering: Boolean? = null
    private var didEmitLoadStartForCurrentItem = false

    // Optional
    private var shareTagElement: String? = null
    private var headerHeight: Float = 0f

    // RN context
    private val trc: ThemedReactContext?
        get() = context as? ThemedReactContext

    private val tickers by lazy {
        RCTVideoTickers(
                hostView = this,
                getReactContext = { context as? ReactContext },
                getViewId = { id },
                getPlayer = { player },
                getIntervalMs = { progressIntervalMs },
                isProgressEnabled = { isProgressEnabled },
                isOnLoadEnabled = { isOnLoadEnabled }
        )
    }

    private val lifecycle =
            object : LifecycleEventListener {
                override fun onHostResume() {
                    isHostResumed = true
                    updatePlayState()
                }
                override fun onHostPause() {
                    isHostResumed = false
                    updatePlayState()
                }
                override fun onHostDestroy() {}
            }

    constructor(context: Context) : super(context) {
        configure()
    }
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        configure()
    }
    constructor(
            context: Context,
            attrs: AttributeSet?,
            defStyleAttr: Int
    ) : super(context, attrs, defStyleAttr) {
        configure()
    }

    private fun configure() {
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
                    p.addListener(createPlayerListener())
                }

        trc?.addLifecycleEventListener(lifecycle)
    }

    @OptIn(UnstableApi::class)
    private fun buildPlayer(): ExoPlayer {
        val ok = HttpStack.get(context)
        val upstream = OkHttpDataSource.Factory(ok)
        return ExoPlayer.Builder(context)
                .setMediaSourceFactory(DefaultMediaSourceFactory(upstream))
                .build()
    }

    // ===== Player listener (gọn) =====
    private fun createPlayerListener(): Player.Listener =
            object : Player.Listener {
                override fun onVideoSizeChanged(size: VideoSize) {
                    val w = size.width
                    val h = (size.height * size.pixelWidthHeightRatio).roundToInt().coerceAtLeast(1)
                    if (w > 0 && h > 0) {
                        videoW = w
                        videoH = h
                        applyAspectNow()
                    }
                }

                override fun onPlaybackStateChanged(state: Int) {
                    when (state) {
                        Player.STATE_BUFFERING -> maybeDispatchBuffering(true)
                        Player.STATE_READY -> {
                            maybeDispatchBuffering(false)
                            maybeEmitOnLoadStartOnce()
                            tickers.startProgressIfNeeded()
                            tickers.startOnLoadIfNeeded()
                        }
                        Player.STATE_ENDED -> {
                            dispatchEnd()
                            maybeDispatchBuffering(false)
                            if (isLooping) {
                                player?.seekTo(0)
                                player?.playWhenReady = true
                            } else {
                                tickers.stopProgress()
                                tickers.stopOnLoad()
                            }
                        }
                        Player.STATE_IDLE -> maybeDispatchBuffering(false)
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    tickers.stopProgress()
                    tickers.stopOnLoad()
                    maybeDispatchBuffering(false)
                    dispatchError(error)
                }
            }

    // ===== View lifecycle =====
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        playerView.player = player
        pendingSource?.let { url ->
            if (url != currentSource) loadSource(url)
            pendingSource = null
        }
        if (hasVideoSize()) applyAspectNow()
        updatePlayState()
        if (shareTagElement != null) shareElement()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        playerView.player = null
        tickers.stopProgress()
        tickers.stopOnLoad()
        lastIsBuffering = null
    }

    fun cleanup() {
        trc?.removeLifecycleEventListener(lifecycle)
        tickers.stopProgress()
        tickers.stopOnLoad()
        RCTVideoTag.removeView(this, shareTagElement)
        playerView.player = null
        player?.release()
        player = null

        currentSource = null
        pendingSource = null
        pendingSeekMs = null
        pendingVolume = null
        videoW = 0
        videoH = 0
        savedSpecsValid = false
        didEmitLoadStartForCurrentItem = false
        lastIsBuffering = null
    }

    // ===== Props (RN) =====
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
        isLooping = loop
        player?.let { applyLoop(it) }
        if (loop && player?.playbackState == Player.STATE_ENDED) {
            player?.seekTo(0)
            player?.playWhenReady = true
        }
    }

    fun setMuted(muted: Boolean) {
        isMuted = muted
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
        if (!isMuted) applyVolume(p, v)
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

    fun setEnableProgress(value: Boolean) {
        isProgressEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) tickers.startProgressIfNeeded()
        else tickers.stopProgress()
    }

    fun setProgressInterval(ms: Double) {
        progressIntervalMs = ms.toLong().coerceAtLeast(50L)
        if (player?.playbackState == Player.STATE_READY && isProgressEnabled)
                tickers.startProgressIfNeeded()
        if (player?.playbackState == Player.STATE_READY && isOnLoadEnabled)
                tickers.startOnLoadIfNeeded()
    }

    fun setEnableOnLoad(value: Boolean) {
        isOnLoadEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) {
            tickers.startOnLoadIfNeeded()
        } else {
            tickers.stopOnLoad()
        }
    }

    fun setHeaderHeight(value: Float) {
        headerHeight = value
    }

    fun setShareTagElement(value: String?) {
        println("setShareTagElement")
        println(shareTagElement)
        shareTagElement = value
        val otherView = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        println(otherView)
    }

    // ===== Events =====
    private fun maybeEmitOnLoadStartOnce() {
        if (didEmitLoadStartForCurrentItem) return
        val p = player ?: return
        if (p.playbackState != Player.STATE_READY) return

        val durSec = if (p.duration > 0) p.duration / 1000.0 else 0.0
        val bufferedSec = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
        val playableSec = if (durSec > 0.0) kotlin.math.min(bufferedSec, durSec) else bufferedSec

        post {
            val reactCtx = context as? ReactContext ?: return@post
            if (!reactCtx.hasActiveCatalystInstance()) return@post
            if (!ViewCompat.isAttachedToWindow(this)) return@post
            val viewId = id.takeIf { it > 0 } ?: return@post
            UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                    ?.dispatchEvent(OnLoadStartEvent(viewId, durSec, playableSec, videoW, videoH))
            didEmitLoadStartForCurrentItem = true
        }
    }

    private fun maybeDispatchBuffering(isBuffering: Boolean) {
        if (lastIsBuffering == isBuffering) return
        lastIsBuffering = isBuffering

        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(OnBufferingEvent(viewId, isBuffering))
    }

    private fun dispatchEnd() {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(OnEndEvent(viewId))
    }

    private fun dispatchError(error: PlaybackException) {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?.dispatchEvent(
                        com.sharevideo.helpers.OnErrorEvent(
                                viewId,
                                RCTVideoErrorUtils.buildErrorMessage(error),
                                RCTVideoErrorUtils.buildErrorCode(error),
                                currentSource
                        )
                )
    }

    // ===== Commands =====
    fun initializeFromCommand() {}
    fun setSeekFromCommand(seekSec: Double) {
        val posMs = (seekSec * 1000.0).toLong().coerceAtLeast(0L)
        player?.seekTo(posMs) ?: run { pendingSeekMs = posMs }
    }
    fun setPausedFromCommand(paused: Boolean) = setPaused(paused)
    fun setVolumeFromCommand(volume: Double) {
        val v = volume.coerceIn(0.0, 1.0)
        player?.let { applyVolume(it, v.toFloat()) } ?: run { pendingVolume = v.toFloat() }
    }

    // ===== Layout helpers (refactor gọn) =====
    private fun hasVideoSize() = videoW > 0 && videoH > 0
    private fun isStretch() = resizeModeStr == "stretch" || resizeModeStr == "fill"

    private fun currentFrameSize(): Pair<Int, Int> {
        val w =
                when {
                    measuredWidth > 0 -> measuredWidth
                    lastWidthPx > 0 -> lastWidthPx
                    else -> width
                }
        val h =
                when {
                    measuredHeight > 0 -> measuredHeight
                    lastHeightPx > 0 -> lastHeightPx
                    else -> height
                }
        return w to h
    }

    private fun layoutChildToRect(rect: Rect) {
        playerView.measure(
                MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    @OptIn(UnstableApi::class)
    private fun applyAspectNow() {
        if (!hasVideoSize()) {
            layoutChildToRect(Rect(0, 0, measuredWidth, measuredHeight))
            return
        }

        if (isStretch()) {
            try {
                playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL
            } catch (_: Throwable) {}
            val (w, h) = currentFrameSize()
            if (w > 0 && h > 0) layoutChildToRect(Rect(0, 0, w, h))
            invalidate()
            return
        }

        if (savedSpecsValid &&
                        lastWidthMode == MeasureSpec.EXACTLY &&
                        lastHeightMode != MeasureSpec.EXACTLY &&
                        lastWidthPx > 0 &&
                        resizeModeStr != "center"
        ) {
            val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
            measureChildren(
                    MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
            )
            setMeasuredDimension(lastWidthPx, targetH)
            getChildAt(0)?.layout(0, 0, lastWidthPx, targetH)
            invalidate()
            return
        }

        val w = if (measuredWidth > 0) measuredWidth else width
        val h = if (measuredHeight > 0) measuredHeight else height
        if (w <= 0 || h <= 0) return
        val rect = RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
        layoutChildToRect(rect)
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        lastWidthPx = MeasureSpec.getSize(widthMeasureSpec)
        lastHeightPx = MeasureSpec.getSize(heightMeasureSpec)
        lastWidthMode = MeasureSpec.getMode(widthMeasureSpec)
        lastHeightMode = MeasureSpec.getMode(heightMeasureSpec)
        savedSpecsValid = true

        val canAutoHeight = RCTVideoLayoutUtils.keepAspect(resizeModeStr) && hasVideoSize()
        val widthExact = lastWidthMode == MeasureSpec.EXACTLY
        val heightNotExact = lastHeightMode != MeasureSpec.EXACTLY

        if (canAutoHeight && widthExact && heightNotExact) {
            val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
            measureChildren(
                    MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
            )
            setMeasuredDimension(lastWidthPx, targetH)
            return
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val w = right - left
        val h = bottom - top
        if (w <= 0 || h <= 0) return

        if (isStretch() || !hasVideoSize()) {
            layoutChildToRect(Rect(0, 0, w, h))
            return
        }
        val rect = RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // ===== Playback helpers =====
    private fun updatePlayState() {
        player?.playWhenReady = (isHostResumed && !externallyPaused)
    }

    private fun applyLoop(p: ExoPlayer) {
        p.repeatMode = if (isLooping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    private fun applyMuted(p: ExoPlayer) {
        if (isMuted) {
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
        videoW = 0
        videoH = 0
        didEmitLoadStartForCurrentItem = false
        lastIsBuffering = null
        tickers.resetOnLoadCache()

        p.setMediaItem(MediaItem.fromUri(url))
        pendingSeekMs?.let {
            p.seekTo(it)
            pendingSeekMs = null
        }

        post {
            p.prepare()
            p.playWhenReady = (isHostResumed && !externallyPaused)
            applyLoop(p)
            applyMuted(p)
        }
    }

    // Share element (tạm debug)
    private fun shareElement() {
        val otherView = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        println("shareTagElement")
        println(shareTagElement)
        println(otherView)
    }
}
