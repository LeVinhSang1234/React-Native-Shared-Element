package com.sharevideo.video

import android.content.Context
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
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
import com.sharevideo.helpers.HttpStack
import com.sharevideo.helpers.OnBufferingEvent
import com.sharevideo.helpers.OnEndEvent
import com.sharevideo.helpers.OnErrorEvent
import com.sharevideo.helpers.OnLoadStartEvent
import com.sharevideo.helpers.RCTVideoErrorUtils
import com.sharevideo.helpers.RCTVideoLayoutUtils
import com.sharevideo.helpers.RCTVideoOverlay
import com.sharevideo.helpers.RCTVideoTag
import com.sharevideo.helpers.RCTVideoTickers
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * RCTVideoView — Video View dùng ExoPlayer (Media3) + PlayerView
 * - Props: source, paused, loop, muted, volume, seek, resizeMode, enableProgress, progressInterval,
 * enableOnLoad, headerHeight(dp), shareTagElement
 * - Events: onLoadStart, onProgress, onLoad, onBuffering, onEnd, onError
 * - Share element: move player của "other" lên overlay để animate; tới đích sync seek "tôi", delay
 * 0.5s, trả player về "other"
 */
class RCTVideoView : FrameLayout {

    // UI
    internal lateinit var playerView: PlayerView
    private var overlay: RCTVideoOverlay? = null

    // Player
    internal var player: ExoPlayer? = null
    private var isSharedPlayer = false

    // Source / playback states
    private var currentSource: String? = null
    private var pendingSource: String? = null
    private var isLooping = false
    private var isMuted = false
    private var rememberedVolume = 1f
    private var externallyPaused = false
    private var isHostResumed = true
    private var pendingSeekMs: Long? = null
    private var pendingVolume: Float? = null

    // Video size + layout
    private var videoW = 0
    private var videoH = 0
    internal var resizeModeStr: String = "contain"
        private set

    // last measure specs
    private var lastWidthPx: Int = 0
    private var lastHeightPx: Int = 0
    private var lastWidthMode: Int = MeasureSpec.UNSPECIFIED
    private var lastHeightMode: Int = MeasureSpec.UNSPECIFIED
    private var savedSpecsValid = false

    // Tickers / events
    private var lastIsBuffering: Boolean? = null
    private var didEmitLoadStartForCurrentItem = false
    private var progressIntervalMs = 250L
    private var isProgressEnabled = false
    private var isOnLoadEnabled = false

    // Share element
    private var shareTagElement: String? = null
    internal var headerHeight: Float = 0f // pixel (convert từ dp khi setProp)

    private var sharingAnimatedDuration: Double = 350.0

    private var isBlurWindow = false

    private var cacheRect: Rect? = null

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

    @OptIn(UnstableApi::class)
    private fun configure() {
        clipChildren = true
        playerView =
                PlayerView(context, null, 0).apply {
                    useController = false
                    setBackgroundColor(android.graphics.Color.TRANSPARENT)
                    setShutterBackgroundColor(android.graphics.Color.TRANSPARENT)
                }
        addView(playerView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        alpha = 0f
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
                                                p.seekTo(0)
                                                p.playWhenReady = true
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
                    )
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

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (isBlurWindow) {
            isBlurWindow = false
            return
        }
        playerView.player = player
        pendingSource?.let { url ->
            if (url != currentSource) loadSource(url)
            pendingSource = null
        }
        if (videoW > 0 && videoH > 0) applyAspectNow()
        updatePlayState()
        if (shareTagElement != null) shareElement()
        else alpha = 1f
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        playerView.player = null
        tickers.stopProgress()
        tickers.stopOnLoad()
        lastIsBuffering = null
        overlay?.unmount()
        overlay = null
        isBlurWindow = true
    }

    fun dealloc() {
        revertShareElement()
    }

    fun cleanup() {
        trc?.removeLifecycleEventListener(lifecycle)
        tickers.stopProgress()
        tickers.stopOnLoad()
        RCTVideoTag.removeView(this, shareTagElement)
        playerView.player = null
        if (!isSharedPlayer) {
            player?.release()
        }
        isSharedPlayer = false
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
        overlay?.unmount()
        overlay = null
        cacheRect = null
    }

    // ===== Props =====
    fun setSource(url: String?) {
        if (url.isNullOrBlank()) return
        player?.let { if (url != currentSource) loadSource(url) } ?: run { pendingSource = url }
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
        if (value && player?.playbackState == Player.STATE_READY) tickers.startOnLoadIfNeeded()
        else tickers.stopOnLoad()
    }

    // headerHeight từ RN là dp -> convert px
    fun setHeaderHeight(value: Float) {
        headerHeight = value * resources.displayMetrics.density
    }

    fun setSharingAnimatedDuration(value: Float) {
        sharingAnimatedDuration = value.toDouble()
    }

    fun setShareTagElement(tag: String?) {
        val newTag = tag?.trim()?.takeIf { it.isNotEmpty() }
        val oldTag = shareTagElement
        if (oldTag != null && oldTag != newTag) {
            RCTVideoTag.removeView(this, oldTag)
        }
        shareTagElement = newTag
        if (newTag != null) {
            RCTVideoTag.registerView(this, newTag)
        }
    }

    // ===== Events helpers =====
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
                        OnErrorEvent(
                                viewId,
                                RCTVideoErrorUtils.buildErrorMessage(error),
                                RCTVideoErrorUtils.buildErrorCode(error),
                                currentSource
                        )
                )
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

    // ===== Layout / aspect =====
    @OptIn(UnstableApi::class)
    private fun applyAspectNow() {
        if (videoW <= 0 || videoH <= 0) {
            layoutChildToRect(Rect(0, 0, measuredWidth, measuredHeight))
            return
        }

        if (resizeModeStr == "stretch" || resizeModeStr == "fill") {
            try {
                playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL
            } catch (_: Throwable) {}
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

    private fun layoutChildToRect(rect: Rect) {
        playerView.measure(
                MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        lastWidthPx = MeasureSpec.getSize(widthMeasureSpec)
        lastHeightPx = MeasureSpec.getSize(heightMeasureSpec)
        lastWidthMode = MeasureSpec.getMode(widthMeasureSpec)
        lastHeightMode = MeasureSpec.getMode(heightMeasureSpec)
        savedSpecsValid = true

        if (RCTVideoLayoutUtils.keepAspect(resizeModeStr) && videoW > 0 && videoH > 0) {
            if (lastWidthMode == MeasureSpec.EXACTLY && lastHeightMode != MeasureSpec.EXACTLY) {
                val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
                measureChildren(
                        MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY),
                        MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
                )
                setMeasuredDimension(lastWidthPx, targetH)
                return
            }
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val w = right - left
        val h = bottom - top
        if (w <= 0 || h <= 0) return
        val rect = RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)

        postDelayed({
            cacheRect = rectForShare(this, 0)
        }, 100)
    }

    // ===== Commands (optional mapping) =====
    fun initializeFromCommand() {}
    fun setSeekFromCommand(seekSec: Double) {
        setSeek(seekSec)
    }
    fun setPausedFromCommand(paused: Boolean) {
        setPaused(paused)
    }
    fun setVolumeFromCommand(volume: Double) {
        val v = volume.coerceIn(0.0, 1.0)
        player?.let { applyVolume(it, v.toFloat()) } ?: run { pendingVolume = v.toFloat() }
    }

    // ===== Share Element (Android version swap iOS) =====
    private fun shareElement() {
        val otherView = RCTVideoTag.getOtherViewForTag(this, shareTagElement)
        if(otherView == null) {
            alpha = 1f
            return
        }
        playerView.player = null
        player?.release()
        player = null
        val movingPlayer = otherView.player ?: return
        val fromRect = rectForShare(otherView, 0)
        otherView.alpha = 0f

        postDelayed({
            val toRect = rectForShare(this)
            cacheRect = toRect
            alpha = 0f
            otherView.playerView.player = null
            val ov = overlay ?: RCTVideoOverlay(context).also { overlay = it }

            val gravityAlias =
                when (resizeModeStr.lowercase()) {
                    "cover" -> "AVLayerVideoGravityResizeAspectFill"
                    "fill", "stretch" -> "AVLayerVideoGravityResize"
                    "center" -> "center"
                    else -> "AVLayerVideoGravityResizeAspect"
                }
            val bgColor =
                (otherView.background as? ColorDrawable)?.color ?: android.graphics.Color.BLACK

            ov.applySharingAnimatedDuration(otherView.sharingAnimatedDuration)
            ov.applyAVLayerVideoGravity(gravityAlias)
            ov.moveToOverlay(
                fromFrame = fromRect,
                targetFrame = toRect,
                player = movingPlayer,
                aVLayerVideoGravity = gravityAlias,
                bgColor = bgColor,
                onTarget = {
                    playerView.player = movingPlayer
                    player = movingPlayer
                    isSharedPlayer = true
                    applyLoop(movingPlayer)
                    applyMuted(movingPlayer)
                    applyAspectNow()
                    setPaused(externallyPaused)
                    alpha = 1f
                },
                onCompleted = {
                    overlay?.unmount()
                    overlay = null
                }
            )
        }, 20)
    }

    fun revertShareElement() {
        val other = RCTVideoTag.getOtherViewForTag(this, shareTagElement) ?: run {
            cleanup(); return
        }
        val movingPlayer = player ?: run { cleanup(); return }
        var fromRect = rectForShare(this, 0)
        alpha = 0f

        if (!ViewCompat.isAttachedToWindow(this) && cacheRect != null) {
            fromRect = cacheRect!!
        }

        val ov = other.overlay ?: RCTVideoOverlay(other.context).also { other.overlay = it }
        val gravityAlias = when (resizeModeStr.lowercase()) {
            "cover" -> "AVLayerVideoGravityResizeAspectFill"
            "fill", "stretch" -> "AVLayerVideoGravityResize"
            "center" -> "center"
            else -> "AVLayerVideoGravityResizeAspect"
        }
        val bgColor = (other.background as? ColorDrawable)?.color ?: android.graphics.Color.BLACK
        println("fromRect $fromRect")

        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        handler.postDelayed({
            val toRect = other.rectForShare(other, 0)
            println("toRect $toRect")

            ov.applySharingAnimatedDuration(other.sharingAnimatedDuration)
            ov.applyAVLayerVideoGravity(gravityAlias)

            ov.moveToOverlay(
                fromFrame = fromRect,
                targetFrame = toRect,
                player = movingPlayer,
                aVLayerVideoGravity = gravityAlias,
                bgColor = bgColor,
                onTarget = {
                    other.playerView.player = movingPlayer
                    other.setPaused(other.externallyPaused)
                    other.applyLoop(other.player!!)
                    other.applyMuted(other.player!!)
                    other.alpha = 1f
                },
                onCompleted = {
                    other.overlay?.unmount()
                    other.overlay = null
                    cleanup()
                }
            )
        }, 10)
    }

    private fun findRoot(): ViewGroup? {
        val act = (context as? ReactContext)?.currentActivity ?: (context as? android.app.Activity)
        return act?.findViewById(android.R.id.content) ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun rectForShare(v: View, extraTopPx: Int = 0): Rect {
        val root = findRoot() ?: return Rect(0, 0, 0, 0)
        val viewLoc = IntArray(2)
        val rootLoc = IntArray(2)
        v.getLocationOnScreen(viewLoc)
        root.getLocationOnScreen(rootLoc)
        val left = viewLoc[0] - rootLoc[0]
        val top = viewLoc[1] - rootLoc[1] + extraTopPx
        return Rect(left, top, left + v.width, top + v.height)
    }
}
