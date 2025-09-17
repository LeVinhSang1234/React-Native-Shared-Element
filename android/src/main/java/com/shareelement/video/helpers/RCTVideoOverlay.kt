package com.shareelement.video.helpers

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.RectEvaluator
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.view.Choreographer
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.facebook.react.bridge.ReactContext

/**
 * Overlay Android tương đương iOS RCTVideoOverlay (không dùng AspectRatioFrameLayout).
 * - Tự layout PlayerView con qua RCTVideoLayoutUtils để giữ tỉ lệ
 * (contain/cover/fill/center/center).
 * - Animate cả vị trí + kích thước bằng ValueAnimator (updateViewLayout mỗi frame).
 * - Luôn đảm bảo overlay nằm trên cùng (elevation + translationZ + bringToFront).
 */
class RCTVideoOverlay(context: Context) : FrameLayout(context) {

    // ===== Config (theo iOS) =====
    private var sharingAnimatedDurationMs: Long = 350L
    private var resizeModeStr: String = "contain" // contain|cover|fill|center

    // ===== Ticking (tương đương CADisplayLink) =====
    private var frameCallback: Choreographer.FrameCallback? = null

    // ===== Runtime state =====
    private var overlayPlayerView: PlayerView? = null
    var player: ExoPlayer? = null
    private var videoW = 0
    private var videoH = 0
    private var currentAnimator: ValueAnimator? = null

    init {
        clipToPadding = true
        clipChildren = true
        setBackgroundColor(Color.TRANSPARENT)
        isClickable = false
        isFocusable = false
        // đảm bảo mặc định cũng nổi trên hầu hết view
        elevation = DEFAULT_ELEV
        translationZ = DEFAULT_ELEV
    }

    // ---------- Gravity (map từ AVLayerVideoGravity) ----------
    fun applyAVLayerVideoGravity(aVLayerVideoGravity: Any?) {
        resizeModeStr =
                when (aVLayerVideoGravity) {
                    is String ->
                            when (aVLayerVideoGravity) {
                                "AVLayerVideoGravityResizeAspect" -> "contain"
                                "AVLayerVideoGravityResizeAspectFill" -> "cover"
                                "AVLayerVideoGravityResize" -> "fill"
                                "aspect", "fit", "contain" -> "contain"
                                "aspectFill", "cover" -> "cover"
                                "fill", "stretch", "resize" -> "fill"
                                "center" -> "center"
                                else -> "contain"
                            }
                    is Int ->
                            when (aVLayerVideoGravity) {
                                0 -> "contain"
                                1 -> "cover"
                                2 -> "fill"
                                3 -> "center"
                                else -> "contain"
                            }
                    else -> "contain"
                }
        requestLayout()
    }

    // ---------- Duration ----------
    fun applySharingAnimatedDuration(durationMs: Double) {
        sharingAnimatedDurationMs = (if (durationMs < 0) 350.0 else durationMs).toLong()
    }

    // ---------- DisplayLink ----------
    fun startTicking() {
        if (frameCallback != null) return
        var cb: Choreographer.FrameCallback? = null
        cb =
                Choreographer.FrameCallback {
                    onTick()
                    if (frameCallback === cb) {
                        Choreographer.getInstance().postFrameCallback(cb)
                    }
                }
        frameCallback = cb
        Choreographer.getInstance().postFrameCallback(cb)
    }

    fun stopTicking() {
        frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameCallback = null
    }

    private fun onTick() {
        val w = width
        val h = height
        if (w <= 0 || h <= 0) return
        layoutChildByAspect(w, h)
    }

    // ---------- Layout child theo aspect (KHÔNG dùng resizeMode của PlayerView) ----------
    private fun layoutChildByAspect(w: Int, h: Int) {
        val pv = overlayPlayerView ?: return
        val rect =
                if (videoW > 0 && videoH > 0)
                        RCTVideoLayoutUtils.computeChildRect(w, h, videoW, videoH, resizeModeStr)
                else Rect(0, 0, w, h)

        pv.measure(
                MeasureSpec.makeMeasureSpec(rect.width(), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(rect.height(), MeasureSpec.EXACTLY)
        )
        pv.layout(rect.left, rect.top, rect.right, rect.bottom)
    }

    // ================== API chính giống iOS ==================
    @OptIn(UnstableApi::class)
    fun moveToOverlay(
            fromFrame: Rect, // pixel - toạ độ theo content/decor
            targetFrame: Rect, // pixel - toạ độ theo content/decor
            player: ExoPlayer,
            aVLayerVideoGravity: Any? = null,
            bgColor: Int? = null,
            onTarget: (() -> Unit)? = null,
            onCompleted: (() -> Unit)? = null
    ) {
        val root = getTargetRoot() ?: return

        // dọn state cũ
        unmount()

        // lưu player + kích thước video nếu có
        this.player = player
        player.videoSize.let { vs: VideoSize ->
            val w = vs.width
            val h = (vs.height * vs.pixelWidthHeightRatio).toInt()
            if (w > 0 && h > 0) {
                videoW = w
                videoH = h
            } else {
                videoW = 0
                videoH = 0
            }
        }

        // init container overlay với fromFrame
        val lp = LayoutParams(fromFrame.width(), fromFrame.height())
        layoutParams = lp
        x = fromFrame.left.toFloat()
        y = fromFrame.top.toFloat()
        setBackgroundColor(bgColor ?: Color.TRANSPARENT)
        clipChildren = true

        // child PlayerView (TextureView trên nhiều OEM; tắt shutter & giữ frame để tránh đen)
        overlayPlayerView =
                PlayerView(context, null, 0).apply {
                    useController = false
                    setBackgroundColor(Color.TRANSPARENT)
                    try {
                        setShutterBackgroundColor(Color.TRANSPARENT)
                    } catch (_: Throwable) {}
                    try {
                        setKeepContentOnPlayerReset(true)
                    } catch (_: Throwable) {}
                    elevation = DEFAULT_ELEV + 1f
                    translationZ = DEFAULT_ELEV + 1f
                    this.player = player
                }
        addView(
                overlayPlayerView,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )

        // map gravity -> resizeModeStr (tự layout qua helper)
        applyAVLayerVideoGravity(aVLayerVideoGravity)

        // add vào root và đảm bảo luôn ở top
        if (parent == null) root.addView(this, lp)
        // root.updateViewLayout(this, lp)
        safeAddOrUpdate(root, this, lp)
        ensureOnTop(root, this)

        // tick để child bám theo bounds trong lúc animate
        startTicking()
        onTick() // layout ngay frame đầu
        // animate position + size (updateViewLayout mỗi frame)
        animateRectViaLp(root, this, fromFrame, targetFrame, sharingAnimatedDurationMs) {
            // đảm bảo layout lần cuối
            onTick()
            stopTicking()
            ensureOnTop(root, this)
            onTarget?.invoke()

            postDelayed(
                    {
                        onCompleted?.invoke()
                        unmount()
                    },
                    100
            )
        }
    }

    private fun safeAddOrUpdate(root: ViewGroup?, view: View, lp: FrameLayout.LayoutParams) {
        try {
            if (root == null) return
            if (view.parent == null) {
                root.addView(view, lp)
            } else if (view.parent === root && view.isAttachedToWindow) {
                root.updateViewLayout(view, lp)
            }
        } catch (_: Exception) {
        }
    }

    fun unmount() {
        overlayPlayerView?.player = null
        overlayPlayerView?.let {
            try {
                removeView(it)
            } catch (_: Throwable) {}
        }
        overlayPlayerView = null

        (parent as? ViewGroup)?.let { vg ->
            try {
                vg.removeView(this)
            } catch (_: Throwable) {}
        }
        stopTicking()

        player = null
        videoW = 0
        videoH = 0
    }

    // ================== Helpers ==================
    private fun getTargetRoot(): ViewGroup? {
        val act: Activity? =
                when (val ctx = context) {
                    is Activity -> ctx
                    is ReactContext -> ctx.currentActivity
                    else -> null
                }
        // Ưu tiên android.R.id.content để nằm trên ReactRootView; fallback decorView
        val content = act?.findViewById<ViewGroup>(android.R.id.content)
        return content ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun ensureOnTop(root: ViewGroup, v: View) {
        v.elevation = DEFAULT_ELEV
        v.translationZ = DEFAULT_ELEV
        v.bringToFront()
        root.requestLayout()
        root.invalidate()
    }

    private fun animateRectViaLp(
            root: ViewGroup,
            overlay: View,
            from: Rect,
            to: Rect,
            durationMs: Long,
            onEnd: (() -> Unit)?
    ) {
        val lp =
                (overlay.layoutParams as? LayoutParams)
                        ?: LayoutParams(from.width(), from.height()).also {
                            overlay.layoutParams = it
                            if (overlay.parent == null) root.addView(overlay, it)
                        }

        // state đầu
        lp.width = from.width()
        lp.height = from.height()
        overlay.x = from.left.toFloat()
        overlay.y = from.top.toFloat()
        //root.updateViewLayout(overlay, lp)
        safeAddOrUpdate(root, overlay, lp)
        ensureOnTop(root, overlay)

        overlay.setLayerType(LAYER_TYPE_HARDWARE, null)

        val eval = RectEvaluator()
        currentAnimator?.cancel()

        currentAnimator = ValueAnimator.ofObject(eval, Rect(from), Rect(to))
                .apply {
                    duration = durationMs
                    interpolator = DecelerateInterpolator()
                    addUpdateListener { va ->
                        val r = va.animatedValue as Rect
                        overlay.x = r.left.toFloat()
                        overlay.y = r.top.toFloat()
                        lp.width = r.width()
                        lp.height = r.height()
                        // root.updateViewLayout(overlay, lp)
                        safeAddOrUpdate(root, overlay, lp)
                        // đảm bảo nằm trên cùng trong suốt quá trình animate
                        ensureOnTop(root, overlay)
                    }
                    addListener(
                            object : AnimatorListenerAdapter() {
                                override fun onAnimationStart(animation: Animator) {
                                    ensureOnTop(root, overlay)
                                }
                                override fun onAnimationEnd(animation: Animator) {
                                    overlay.setLayerType(LAYER_TYPE_NONE, null)
                                    ensureOnTop(root, overlay)
                                    onEnd?.invoke()
                                }
                            }
                    )
                }
        currentAnimator?.start()
    }

    // giữ aspect kể cả khi parent tự layout lại ngoài animation
    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        layoutChildByAspect(r - l, b - t)
    }

    companion object {
        private const val DEFAULT_ELEV = 100000f
    }
}
