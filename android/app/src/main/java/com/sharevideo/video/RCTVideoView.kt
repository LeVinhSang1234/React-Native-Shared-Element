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
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Custom View phát video dùng ExoPlayer (Media3) + PlayerView
 *
 * Tính năng chính:
 * - Nhận props từ React Native: source, paused, loop, muted, volume, seek, resizeMode,
 *   enableProgress, progressInterval, enableOnLoad
 * - Tự xử lý đo/là­y­out để giữ tỉ lệ khi cần (contain/cover/center) hoặc kéo giãn (stretch/fill)
 * - Phát sự kiện RN:
 *     onLoadStart { duration, playableDuration, width, height }
 *     onProgress  { currentTime, duration?, playableDuration }
 *     onLoad      { loadedDuration, duration }  // khi enableOnLoad & có thay đổi
 *     onBuffering { isBuffering }
 *     onError     { message, code?, track? }
 */
class RCTVideoView : FrameLayout {

    // View hiển thị video (không hiện controller)
    private lateinit var playerView: PlayerView
    // Đối tượng ExoPlayer
    private var player: ExoPlayer? = null

    // URL đang phát hiện tại
    private var currentSource: String? = null
    // URL chờ phát (khi player chưa sẵn sàng/attached)
    private var pendingSource: String? = null

    // Cờ lặp lại
    private var isLooping = false
    // Cờ tắt tiếng
    private var isMuted = false
    // Lưu volume khi bật mute để khôi phục
    private var rememberedVolume = 1f
    // Cờ pause từ phía RN
    private var externallyPaused = false
    // Cờ lifecycle: host (Activity) đang resumed hay không
    private var isHostResumed = true

    // Thời điểm seek (ms) cần apply khi player sẵn sàng
    private var pendingSeekMs: Long? = null
    // Volume cần apply khi player sẵn sàng
    private var pendingVolume: Float? = null

    // Kích thước video thực tế (tính theo pixel ratio)
    private var videoW = 0
    private var videoH = 0

    // Chế độ resize: contain|cover|stretch|fill|center
    private var resizeModeStr: String = "contain"

    // Lưu lại MeasureSpec gần nhất để xử lý case auto-height
    private var lastWidthPx: Int = 0
    private var lastHeightPx: Int = 0
    private var lastWidthMode: Int = MeasureSpec.UNSPECIFIED
    private var lastHeightMode: Int = MeasureSpec.UNSPECIFIED
    private var savedSpecsValid = false

    // Khoảng tick phát onProgress/onLoad (ms)
    private var progressIntervalMs = 250L
    // Bật/tắt tick onProgress
    private var isProgressEnabled = false

    // Bật/tắt tick onLoad (report loadedDuration/duration)
    private var isOnLoadEnabled = false
    // Giá trị gần nhất đã gửi cho onLoad (để chỉ gửi khi thay đổi)
    private var lastOnLoadLoaded: Double? = null
    private var lastOnLoadDuration: Double? = null

    // Trạng thái buffering lần cuối (để tránh dispatch trùng)
    private var lastIsBuffering: Boolean? = null

    // Tránh emit onLoadStart nhiều lần cho cùng media item
    private var didEmitLoadStartForCurrentItem = false

    // Tiện để lấy ReactContext nếu view được tạo từ ThemedReactContext
    private val trc: ThemedReactContext?
        get() = context as? ThemedReactContext

    // Lắng nghe lifecycle của React Native host (Activity)
    private val lifecycle = object : LifecycleEventListener {
        override fun onHostResume() {
            // Host resumed -> nếu không bị pause bởi RN thì chơi tiếp
            isHostResumed = true
            updatePlayState()
        }
        override fun onHostPause() {
            // Host pause -> tạm dừng phát (không giải phóng)
            isHostResumed = false
            updatePlayState()
        }
        override fun onHostDestroy() {
            // Cleanup trong cleanup()
        }
    }

    // 3 constructor chuẩn của View
    constructor(context: Context) : super(context) { configure() }
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) { configure() }
    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr) { configure() }

    // Khởi tạo view và player
    private fun configure() {
        clipChildren = true // cắt phần dư của child (phục vụ crop/cover)

        // Tạo PlayerView không có controller
        playerView = PlayerView(context, null, 0).apply { useController = false }
        // Thêm PlayerView full-size
        addView(playerView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        // Tạo ExoPlayer và gắn listener
        player = buildPlayer().also { p ->
            playerView.player = p // gán player cho PlayerView
            applyLoop(p)          // set repeat mode theo isLooping hiện tại
            applyMuted(p)         // set mute/volume theo cờ hiện tại
            pendingVolume?.let { applyVolume(p, it); pendingVolume = null } // apply volume pending

            // Lắng nghe các thay đổi từ Player
            p.addListener(object : Player.Listener {
                // Khi kích thước video thay đổi -> cập nhật và layout lại
                override fun onVideoSizeChanged(size: VideoSize) {
                    val w = size.width
                    val h = (size.height * size.pixelWidthHeightRatio).roundToInt().coerceAtLeast(1)
                    if (w > 0 && h > 0) {
                        videoW = w
                        videoH = h
                        applyAspectNow()
                    }
                }

                // Khi state phát thay đổi
                override fun onPlaybackStateChanged(state: Int) {
                    when (state) {
                        Player.STATE_BUFFERING -> {
                            // báo đang buffering
                            maybeDispatchBuffering(true)
                        }
                        Player.STATE_READY -> {
                            // hết buffering, đã sẵn sàng
                            maybeDispatchBuffering(false)
                            // emit onLoadStart 1 lần cho media này
                            maybeEmitOnLoadStartOnce()
                            // khởi động tick onProgress nếu bật
                            startProgressIfNeeded()
                            // khởi động tick onLoad nếu bật
                            startOnLoadIfNeeded()
                        }
                        Player.STATE_ENDED -> {
                            dispatchEnd()

                            // Không còn buffering
                            maybeDispatchBuffering(false)
                            if (isLooping) {
                                // Nếu loop -> quay về 0 và chơi tiếp
                                p.seekTo(0)
                                p.playWhenReady = true
                            } else {
                                // Không loop -> dừng các ticker
                                stopProgress()
                                stopOnLoad()
                            }
                        }
                        Player.STATE_IDLE -> {
                            // IDLE coi như không buffering
                            maybeDispatchBuffering(false)
                        }
                    }
                }

                // Khi có lỗi phát
                override fun onPlayerError(error: PlaybackException) {
                    // Ngừng ticker và báo lỗi
                    stopProgress()
                    stopOnLoad()
                    maybeDispatchBuffering(false)
                    dispatchError(error)
                }
            })
        }

        // Đăng ký lifecycle RN
        trc?.addLifecycleEventListener(lifecycle)
    }

    // Tạo ExoPlayer + MediaSourceFactory dùng OkHttp (có cache theo HttpStack)
    @OptIn(UnstableApi::class)
    private fun buildPlayer(): ExoPlayer {
        val ok = HttpStack.get(context) // OkHttp client có cache 1 ngày (do bạn tự cài)
        val upstream = OkHttpDataSource.Factory(ok)
        return ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(upstream))
            .build()
    }

    // View được gắn vào window
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        playerView.player = player // gắn lại player vào view (phòng trường hợp bị null)
        // Nếu có source pending thì load
        pendingSource?.let { url ->
            if (url != currentSource) loadSource(url)
            pendingSource = null
        }
        // Nếu đã biết kích thước video thì áp aspect ngay
        if (videoW > 0 && videoH > 0) applyAspectNow()
        // Cập nhật trạng thái play/pause theo lifecycle + pause ngoài
        updatePlayState()
    }

    // View bị tháo khỏi window
    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        playerView.player = null // bỏ tham chiếu để tránh leak
        stopProgress()           // dừng progress ticker
        stopOnLoad()             // dừng onLoad ticker
        lastIsBuffering = null   // reset trạng thái buffering
    }

    // Giải phóng tài nguyên khi RN unmount component
    fun cleanup() {
        trc?.removeLifecycleEventListener(lifecycle)
        stopProgress()
        stopOnLoad()
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
        lastOnLoadLoaded = null
        lastOnLoadDuration = null
        lastIsBuffering = null
    }

    // ======== API từ RN (setter cho props) ========

    // Đặt URL nguồn phát
    fun setSource(url: String?) {
        if (url.isNullOrBlank()) return
        val p = player
        if (p == null) {
            // Player chưa sẵn sàng -> lưu vào pending
            pendingSource = url
            return
        }
        if (url == currentSource) return // tránh reload lại cùng URL
        loadSource(url) // load nguồn mới
    }

    // Pause/Resume từ phía RN
    fun setPaused(paused: Boolean) {
        externallyPaused = paused
        updatePlayState()
    }

    // Bật tắt loop
    fun setLoop(loop: Boolean) {
        isLooping = loop
        player?.let { applyLoop(it) }
        // Nếu đang ở END và bật loop -> play lại từ đầu
        if (loop && player?.playbackState == Player.STATE_ENDED) {
            player?.seekTo(0)
            player?.playWhenReady = true
        }
    }

    // Bật tắt mute
    fun setMuted(muted: Boolean) {
        isMuted = muted
        player?.let { applyMuted(it) }
    }

    // Đặt volume (0..1)
    fun setVolume(vol: Double) {
        val v = vol.toFloat().coerceIn(0f, 1f)
        val p = player
        if (p == null) {
            pendingVolume = v // lưu lại để set sau
            return
        }
        rememberedVolume = v // lưu để restore khi unmute
        if (!isMuted) applyVolume(p, v)
    }

    // Seek tới vị trí (giây)
    fun setSeek(seconds: Double) {
        val ms = max(0L, (seconds * 1000.0).toLong())
        val p = player
        if (p == null || p.mediaItemCount == 0) {
            pendingSeekMs = ms // chưa load xong -> lưu lại
            return
        }
        p.seekTo(ms)
    }

    // Đặt chế độ resize cho video
    fun setResizeMode(mode: String?) {
        resizeModeStr = (mode ?: "contain").lowercase().trim()
        applyAspectNow()
    }

    // Bật tắt tick onProgress
    fun setEnableProgress(value: Boolean) {
        isProgressEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) startProgressIfNeeded() else stopProgress()
    }

    // Đặt khoảng tick (ms) cho progress & onLoad
    fun setProgressInterval(ms: Double) {
        progressIntervalMs = ms.toLong().coerceAtLeast(50L)
        if (player?.playbackState == Player.STATE_READY && isProgressEnabled) startProgressIfNeeded()
        if (player?.playbackState == Player.STATE_READY && isOnLoadEnabled) startOnLoadIfNeeded()
    }

    // Bật tắt tick onLoad (bắn loadedDuration/duration khi thay đổi)
    fun setEnableOnLoad(value: Boolean) {
        isOnLoadEnabled = value
        if (value && player?.playbackState == Player.STATE_READY) {
            startOnLoadIfNeeded()
        } else {
            stopOnLoad()
        }
    }

    // ======== Định nghĩa các RN Event ========

    // Sự kiện onLoadStart
    private class OnLoadStartEvent(
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
            val map = Arguments.createMap().apply {
                putDouble("duration", durationSec)
                putDouble("playableDuration", playableDurationSec)
                putDouble("width", widthPx.toDouble())
                putDouble("height", heightPx.toDouble())
            }
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    // Sự kiện onProgress
    private class OnProgressEvent(
        viewId: Int,
        private val positionSec: Double,
        private val durationSec: Double?,
        private val playableDurationSec: Double
    ) : Event<OnProgressEvent>(viewId) {
        override fun getEventName() = "onProgress"
        override fun canCoalesce() = true
        // Key cho coalescing: thời gian hiện tại * 10
        override fun getCoalescingKey(): Short = (positionSec * 10).toInt().toShort()
        @Deprecated("Prefer to override getEventData instead")
        override fun dispatch(rctEventEmitter: RCTEventEmitter) {
            val map = Arguments.createMap().apply {
                putDouble("currentTime", positionSec)
                durationSec?.let { putDouble("duration", it) }
                putDouble("playableDuration", playableDurationSec)
            }
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    // Sự kiện onLoad (report loadedDuration/duration)
    private class OnLoadEvent(
        viewId: Int,
        private val loadedDurationSec: Double,
        private val durationSec: Double
    ) : Event<OnLoadEvent>(viewId) {
        override fun getEventName() = "onLoad"
        override fun canCoalesce() = false
        @Deprecated("Prefer to override getEventData instead")
        override fun dispatch(rctEventEmitter: RCTEventEmitter) {
            val map = Arguments.createMap().apply {
                putDouble("loadedDuration", loadedDurationSec)
                putDouble("duration", durationSec)
            }
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    // Sự kiện onBuffering (báo đang/không buffering)
    private class OnBufferingEvent(
        viewId: Int,
        private val isBuffering: Boolean
    ) : Event<OnBufferingEvent>(viewId) {
        override fun getEventName() = "onBuffering"
        override fun canCoalesce() = false
        @Deprecated("Prefer to override getEventData instead")
        override fun dispatch(rctEventEmitter: RCTEventEmitter) {
            val map = Arguments.createMap().apply {
                putBoolean("isBuffering", isBuffering)
            }
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    // Sự kiện onEnd
    private class OnEndEvent(
        viewId: Int
    ) : Event<OnEndEvent>(viewId) {
        override fun getEventName() = "onEnd"
        override fun canCoalesce() = false
        @Deprecated("Prefer to override getEventData instead")
        override fun dispatch(rctEventEmitter: RCTEventEmitter) {
            // không payload
            val map = Arguments.createMap()
            rctEventEmitter.receiveEvent(viewTag, eventName, map)
        }
    }

    // Sự kiện onError
    private class OnErrorEvent(
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

    // Chỉ emit onLoadStart 1 lần mỗi khi media READY lần đầu
    private fun maybeEmitOnLoadStartOnce() {
        if (didEmitLoadStartForCurrentItem) return
        val p = player ?: return
        if (p.playbackState != Player.STATE_READY) return

        // Tính duration & playableDuration (min(buffered, duration))
        val durSec = if (p.duration > 0) p.duration / 1000.0 else 0.0
        val bufferedSec = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
        val playableSec = if (durSec > 0.0) kotlin.math.min(bufferedSec, durSec) else bufferedSec

        // Dispatch event trên UI thread
        post {
            val reactCtx = context as? ReactContext ?: return@post
            if (!reactCtx.hasActiveCatalystInstance()) return@post
            if (!ViewCompat.isAttachedToWindow(this)) return@post

            val viewId = id.takeIf { it > 0 } ?: return@post
            val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId) ?: return@post
            dispatcher.dispatchEvent(OnLoadStartEvent(viewId, durSec, playableSec, videoW, videoH))
            didEmitLoadStartForCurrentItem = true
        }
    }

    // Runnable gửi onProgress theo interval
    private val progressTick = object : Runnable {
        override fun run() {
            if (!isProgressEnabled) return
            val p = player ?: run { postDelayed(this, progressIntervalMs); return }
            val reactCtx = context as? ReactContext ?: run { postDelayed(this, progressIntervalMs); return }
            if (!reactCtx.hasActiveCatalystInstance()) { postDelayed(this, progressIntervalMs); return }

            val viewId = id.takeIf { it > 0 } ?: run { postDelayed(this, progressIntervalMs); return }
            val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?: run { postDelayed(this, progressIntervalMs); return }

            // currentTime/duration/buffered
            val pos = (p.currentPosition.coerceAtLeast(0L)) / 1000.0
            val dur = if (p.duration > 0) p.duration / 1000.0 else null
            val buf = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
            val playableSec = dur?.let { minOf(buf, it) } ?: buf

            dispatcher.dispatchEvent(OnProgressEvent(viewId, pos, dur, playableSec))
            postDelayed(this, progressIntervalMs) // lên lịch tick tiếp theo
        }
    }

    // Bắt đầu tick onProgress nếu được bật
    private fun startProgressIfNeeded() {
        stopProgress() // tránh double-schedule
        if (!isProgressEnabled) return
        postDelayed(progressTick, progressIntervalMs)
    }

    // Dừng tick onProgress
    private fun stopProgress() {
        removeCallbacks(progressTick)
    }

    // Runnable gửi onLoad theo interval (riêng với progress)
    private val onLoadTick = object : Runnable {
        override fun run() {
            if (!isOnLoadEnabled) return
            val p = player ?: run { postDelayed(this, progressIntervalMs); return }
            if (p.playbackState != Player.STATE_READY) { postDelayed(this, progressIntervalMs); return }

            val reactCtx = context as? ReactContext ?: run { postDelayed(this, progressIntervalMs); return }
            if (!reactCtx.hasActiveCatalystInstance()) { postDelayed(this, progressIntervalMs); return }

            val viewId = id.takeIf { it > 0 } ?: run { postDelayed(this, progressIntervalMs); return }
            val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId)
                ?: run { postDelayed(this, progressIntervalMs); return }

            // Tính loadedDuration/duration
            val loaded = (p.bufferedPosition.coerceAtLeast(0L)) / 1000.0
            val duration = if (p.duration > 0) p.duration / 1000.0 else 0.0

            // Chỉ dispatch khi có thay đổi
            val changed = hasOnLoadChanged(loaded, duration)
            if (changed) {
                dispatcher.dispatchEvent(OnLoadEvent(viewId, loaded, duration))
                lastOnLoadLoaded = loaded
                lastOnLoadDuration = duration
            }
            postDelayed(this, progressIntervalMs)
        }
    }

    // Kiểm tra loaded/duration có thay đổi đáng kể (epsilon nhỏ) so với lần trước không
    private fun hasOnLoadChanged(loaded: Double, duration: Double): Boolean {
        val prevLoaded = lastOnLoadLoaded
        val prevDuration = lastOnLoadDuration
        val eps = 1e-3
        return prevLoaded == null ||
               prevDuration == null ||
               abs(loaded - prevLoaded) > eps ||
               abs(duration - prevDuration) > eps
    }

    // Bắt đầu tick onLoad nếu bật và player đã READY
    private fun startOnLoadIfNeeded() {
        stopOnLoad() // tránh double-schedule
        if (!isOnLoadEnabled) return
        if (player?.playbackState != Player.STATE_READY) return
        lastOnLoadLoaded = null
        lastOnLoadDuration = null
        post(onLoadTick)
    }

    // Dừng tick onLoad
    private fun stopOnLoad() {
        removeCallbacks(onLoadTick)
    }

    // Gửi onBuffering nếu trạng thái có thay đổi
    private fun maybeDispatchBuffering(isBuffering: Boolean) {
        if (lastIsBuffering == isBuffering) return // tránh gửi trùng
        lastIsBuffering = isBuffering

        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId) ?: return
        dispatcher.dispatchEvent(OnBufferingEvent(viewId, isBuffering))
    }

    // ======== Helper playback ========

    // Cập nhật playWhenReady dựa trên hostResumed & externallyPaused
    private fun updatePlayState() {
        player?.playWhenReady = (isHostResumed && !externallyPaused)
    }

    // Áp repeat mode
    private fun applyLoop(p: ExoPlayer) {
        p.repeatMode = if (isLooping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    // Áp mute/volume
    private fun applyMuted(p: ExoPlayer) {
        if (isMuted) {
            if (p.volume > 0f) rememberedVolume = p.volume // lưu volume hiện tại
            p.volume = 0f
        } else {
            applyVolume(p, rememberedVolume)
        }
    }

    // Set volume có clamp [0..1]
    private fun applyVolume(p: ExoPlayer, v: Float) {
        p.volume = v.coerceIn(0f, 1f)
    }

    // Load media từ URL và chuẩn bị phát
    private fun loadSource(url: String) {
        val p = player ?: return

        currentSource = url          // cập nhật nguồn hiện tại
        videoW = 0; videoH = 0       // reset kích thước video
        didEmitLoadStartForCurrentItem = false
        lastOnLoadLoaded = null
        lastOnLoadDuration = null
        lastIsBuffering = null

        p.setMediaItem(MediaItem.fromUri(url)) // set media item
        // Nếu có seek pending -> apply luôn
        pendingSeekMs?.let { p.seekTo(it); pendingSeekMs = null }

        // Chuẩn bị và bắt đầu phát (nếu không bị pause)
        post {
            p.prepare()
            p.playWhenReady = (isHostResumed && !externallyPaused)
            applyLoop(p)
            applyMuted(p)
        }
    }

    // ======== Tính toán layout/aspect ========

    // Có giữ tỉ lệ (true) hay kéo giãn (false)
    private fun keepAspect(): Boolean = resizeModeStr != "stretch" && resizeModeStr != "fill"

    // Tính layout cho PlayerView dựa trên kích thước video & resizeMode
    @OptIn(UnstableApi::class)
    private fun applyAspectNow() {
        if (videoW <= 0 || videoH <= 0) {
            // Chưa biết size -> fill khung hiện tại
            layoutChildToRect(Rect(0, 0, measuredWidth, measuredHeight))
            return
        }

        // Trường hợp stretch/fill: kéo giãn full khung
        if (resizeModeStr == "stretch" || resizeModeStr == "fill") {
            try { playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL } catch (_: Throwable) {}
            val w = when {
                measuredWidth > 0 -> measuredWidth
                lastWidthPx > 0 -> lastWidthPx
                else -> width
            }
            val h = when {
                measuredHeight > 0 -> measuredHeight
                lastHeightPx > 0 -> lastHeightPx
                else -> height
            }
            if (w > 0 && h > 0) layoutChildToRect(Rect(0, 0, w, h))
            invalidate()
            return
        }

        // Trường hợp auto-height: width EXACTLY & height !EXACTLY & không phải center
        if (savedSpecsValid &&
            lastWidthMode == MeasureSpec.EXACTLY &&
            lastHeightMode != MeasureSpec.EXACTLY &&
            lastWidthPx > 0 &&
            resizeModeStr != "center"
        ) {
            val targetH = (lastWidthPx.toFloat() * videoH / videoW).toInt().coerceAtLeast(1)
            // Đo child theo kích thước mục tiêu
            measureChildren(
                MeasureSpec.makeMeasureSpec(lastWidthPx, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
            )
            // Set kích thước chính View
            setMeasuredDimension(lastWidthPx, targetH)
            // Layout child full bên trong
            getChildAt(0)?.layout(0, 0, lastWidthPx, targetH)
            invalidate()
            return
        }

        // Khung cố định -> tính rect con theo resizeMode & layout
        val w = if (measuredWidth > 0) measuredWidth else width
        val h = if (measuredHeight > 0) measuredHeight else height
        if (w <= 0 || h <= 0) return

        val rect = computeChildRect(w, h)
        layoutChildToRect(rect)
        invalidate()
    }

    // Đo + layout PlayerView vào rect cho trước
    private fun layoutChildToRect(rect: Rect) {
        playerView.measure(
            MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // Tính rect con theo resizeMode bên trong khung w*h
    private fun computeChildRect(w: Int, h: Int): Rect {
        val rect = Rect(0, 0, w, h)
        if (videoW <= 0 || videoH <= 0) return rect

        return when (resizeModeStr) {
            "stretch", "fill" -> rect // kéo giãn full

            "center" -> {
                // không scale, chỉ canh giữa; bị cắt nếu vượt khung
                val targetW = videoW.coerceAtMost(w)
                val targetH = videoH.coerceAtMost(h)
                val left = (w - targetW) / 2
                val top = (h - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }

            "cover" -> {
                // phủ kín bằng cách scale lớn hơn (có crop)
                val scale = maxOf(w / videoW.toFloat(), h / videoH.toFloat())
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (w - targetW) / 2
                val top  = (h - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }

            else -> { // contain: giữ tỉ lệ, lọt trong khung
                val scale = minOf(w / videoW.toFloat(), h / videoH.toFloat())
                val targetW = (videoW * scale).roundToInt().coerceAtLeast(1)
                val targetH = (videoH * scale).roundToInt().coerceAtLeast(1)
                val left = (w - targetW) / 2
                val top  = (h - targetH) / 2
                Rect(left, top, left + targetW, top + targetH)
            }
        }
    }

    // Lưu lại MeasureSpec và xử lý auto-height khi có thể
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // Lưu thông tin measure cho lần applyAspect sau
        lastWidthPx = MeasureSpec.getSize(widthMeasureSpec)
        lastHeightPx = MeasureSpec.getSize(heightMeasureSpec)
        lastWidthMode = MeasureSpec.getMode(widthMeasureSpec)
        lastHeightMode = MeasureSpec.getMode(heightMeasureSpec)
        savedSpecsValid = true

        // Nếu cần giữ tỉ lệ và đã biết kích thước video
        if (keepAspect() && videoW > 0 && videoH > 0) {
            // Case: width EXACTLY, height !EXACTLY -> tính chiều cao theo tỉ lệ
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
        // Mặc định dùng onMeasure của FrameLayout
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    // Mỗi lần layout -> đặt PlayerView theo rect tính từ resizeMode
    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val w = right - left
        val h = bottom - top
        if (w <= 0 || h <= 0) return
        val rect = computeChildRect(w, h)
        playerView.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // ======== Mapping & dispatch lỗi, end ========

    // Gửi onEnd ra RN
    private fun dispatchEnd() {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId) ?: return
        dispatcher.dispatchEvent(OnEndEvent(viewId))
    }

    // Gửi onError ra RN
    private fun dispatchError(error: PlaybackException) {
        val reactCtx = context as? ReactContext ?: return
        if (!reactCtx.hasActiveCatalystInstance()) return
        val viewId = id.takeIf { it > 0 } ?: return
        val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactCtx, viewId) ?: return

        val code = buildErrorCode(error)         // ví dụ: HTTP_404, NETWORK, IO, ...
        val message = buildErrorMessage(error)   // mô tả ngắn gọn + HTTP status nếu có
        val track = currentSource                // URL đang phát

        dispatcher.dispatchEvent(OnErrorEvent(viewId, message, code, track))
    }

    // Suy ra code lỗi: ưu tiên HTTP status, sau đó network, IO, rồi fallback theo Media3
    private fun buildErrorCode(e: PlaybackException): String? {
        val cause = e.cause

        // HTTP status cụ thể
        if (cause is HttpDataSource.InvalidResponseCodeException) {
            return "HTTP_${cause.responseCode}"
        }

        // Network theo errorCode chuẩn và theo loại exception thường gặp
        if (e.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED ||
            e.errorCode == PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ||
            isNetworkIssue(cause)
        ) {
            return "NETWORK"
        }

        // IO nói chung
        if (cause is IOException) {
            return "IO"
        }

        // Fallback tên mã lỗi chuẩn của Media3
        return e.errorCodeName
    }

    // Nhận diện các lỗi mạng phổ biến từ cause chain
    private fun isNetworkIssue(t: Throwable?): Boolean {
        var c = t
        while (c != null) {
            when (c) {
                is UnknownHostException,
                is SocketTimeoutException,
                is ConnectException,
                is SSLException -> return true
            }
            c = c.cause
        }
        return false
    }

    // Tạo message hiển thị, kèm (HTTP xxx) nếu là lỗi HTTP
    private fun buildErrorMessage(e: PlaybackException): String {
        val base = e.message ?: e.errorCodeName
        val cause = e.cause
        return if (cause is HttpDataSource.InvalidResponseCodeException) {
            "$base (HTTP ${cause.responseCode})"
        } else {
            base
        }
    }
}
