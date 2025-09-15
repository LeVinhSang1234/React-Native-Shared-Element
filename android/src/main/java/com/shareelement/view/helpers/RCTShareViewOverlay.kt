package com.shareelement.view.helpers

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.facebook.react.bridge.ReactContext
import android.widget.TextView
import android.widget.ImageView
import androidx.annotation.RequiresApi
import android.util.Log
import android.util.TypedValue
import android.net.Uri
import com.facebook.drawee.view.SimpleDraweeView

class RCTShareViewOverlay(context: Context) : FrameLayout(context) {
    init {
        setBackgroundColor(0x880000FF.toInt())
    }
    companion object {
        private const val DEFAULT_ELEV = 9999f
    }

    private var overlayChild: View? = null

    @RequiresApi(Build.VERSION_CODES.P)
    fun moveToOverlay(
        fromFrame: Rect,
        toFrame: Rect,
        fromView: View,
        toView: View,
        duration: Long = 300,
        onTarget: (() -> Unit)? = null,
        onCompleted: (() -> Unit)? = null
    ) {
        val root = getTargetRoot() ?: return
        removeAllViews()

        // ✅ Clone fromView
        val clone = deepCloneView(fromView)
        addView(clone)

        // ✅ Setup overlay start frame
        layoutParams = FrameLayout.LayoutParams(fromFrame.width(), fromFrame.height())
        x = fromFrame.left.toFloat()
        y = fromFrame.top.toFloat()

        if (parent == null) {
            root.addView(this, layoutParams)
        } else {
            root.updateViewLayout(this, layoutParams)
        }
        ensureOnTop(root, this)

        fromView.alpha = 0f
        toView.alpha = 0f

        ValueAnimator.ofFloat(0f, 1f).apply {
            this.duration = duration
            addUpdateListener { anim ->
                val f = anim.animatedFraction
                val newW = (fromFrame.width() + (toFrame.width() - fromFrame.width()) * f).toInt()
                val newH = (fromFrame.height() + (toFrame.height() - fromFrame.height()) * f).toInt()
                val newX = fromFrame.left + ((toFrame.left - fromFrame.left) * f).toInt()
                val newY = fromFrame.top + ((toFrame.top - fromFrame.top) * f).toInt()

                val curLp = layoutParams as LayoutParams
                curLp.width = newW
                curLp.height = newH
                root.updateViewLayout(this@RCTShareViewOverlay, curLp)

                x = newX.toFloat()
                y = newY.toFloat()
                clone.layoutParams = curLp
            }

            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: Animator) {
                    if (fromView is ViewGroup && toView is ViewGroup && clone is ViewGroup) {
                        animateSubviews(toView, clone, duration)
                    }
                }

                override fun onAnimationEnd(animation: Animator) {
                    onTarget?.invoke()
                    postDelayed({
                        onCompleted?.invoke()
                        didUnmount()
                    }, 80)
                }
            })
            start()
        }
    }

    private fun animateSubviews(
        toView: ViewGroup,
        ghostView: ViewGroup,
        duration: Long
    ) {
        Log.d(
            "RCTShareViewOverlay",
            "👉 animateSubviews: ghost=${ghostView.javaClass.simpleName}, to=${toView.javaClass.simpleName}, ghostChildCount=${ghostView.childCount}, toChildCount=${toView.childCount}"
        )

        val used = mutableSetOf<View>()

        for (i in 0 until ghostView.childCount) {
            val ghostChild = ghostView.getChildAt(i)
            val toChild = findMatchingChild(ghostChild, toView, used)

            if (toChild == null) {
                Log.d(
                    "RCTShareViewOverlay",
                    "❌ No match for ghostChild[$i]=${ghostChild.javaClass.simpleName}"
                )
                continue
            }

            Log.d(
                "RCTShareViewOverlay",
                "✅ Matched ghostChild[$i]=${ghostChild.javaClass.simpleName} with toChild=${toChild.javaClass.simpleName}"
            )

            val startW = ghostChild.width
            val startH = ghostChild.height
            val startX = ghostChild.x
            val startY = ghostChild.y

            val endW = toChild.width
            val endH = toChild.height
            val endX = toChild.x
            val endY = toChild.y

            Log.d(
                "RCTShareViewOverlay",
                "   ↪ animating ${ghostChild.javaClass.simpleName}: start=($startX,$startY,$startW,$startH) → end=($endX,$endY,$endW,$endH)"
            )

            when {
                // --- TextView ---
                ghostChild is TextView && toChild is TextView -> {
                    ghostChild.animate()
                        .x(endX)
                        .y(endY)
                        .setDuration(duration)
                        .start()

                    val startSize = ghostChild.textSize
                    val endSize = toChild.textSize
                    ValueAnimator.ofFloat(startSize, endSize).apply {
                        this.duration = duration
                        addUpdateListener { anim ->
                            val newSize = anim.animatedValue as Float
                            ghostChild.setTextSize(TypedValue.COMPLEX_UNIT_PX, newSize)
                        }
                        start()
                    }
                    ghostChild.setTextColor(toChild.currentTextColor)
                }

                // --- ImageView ---
                ghostChild is ImageView && toChild is ImageView -> {
                    val scaleXFactor = if (startW != 0) endW.toFloat() / startW else 1f
                    val scaleYFactor = if (startH != 0) endH.toFloat() / startH else 1f

                    ghostChild.pivotX = 0f
                    ghostChild.pivotY = 0f

                    ghostChild.animate()
                        .x(endX)
                        .y(endY)
                        .scaleX(scaleXFactor)
                        .scaleY(scaleYFactor)
                        .setDuration(duration)
                        .withEndAction {
                            ghostChild.scaleType = toChild.scaleType
                            Log.d("RCTShareViewOverlay", "   ✔ ImageView animation done")
                        }
                        .start()
                }

                // --- View thường ---
                else -> {
                    ghostChild.animate()
                        .x(endX)
                        .y(endY)
                        .setDuration(duration)
                        .start()

                    ValueAnimator.ofFloat(0f, 1f).apply {
                        this.duration = duration
                        addUpdateListener { anim ->
                            val f = anim.animatedFraction
                            ghostChild.layoutParams = ghostChild.layoutParams.apply {
                                width = (startW + (endW - startW) * f).toInt()
                                height = (startH + (endH - startH) * f).toInt()
                            }
                            ghostChild.requestLayout()
                        }
                        start()
                    }
                }
            }

            // --- Recursive cho group con ---
            if (ghostChild is ViewGroup && toChild is ViewGroup) {
                animateSubviews(toChild, ghostChild, duration)
            }
        }
    }

    private fun findMatchingChild(
        fromChild: View,
        toParent: ViewGroup,
        used: MutableSet<View>
    ): View? {
        Log.d(
            "RCTShareViewOverlay",
            "🔍 findMatchingChild: fromChild=${fromChild.javaClass.simpleName}, toParentChildCount=${toParent.childCount}"
        )

        val fromName = fromChild.javaClass.simpleName

        for (i in 0 until toParent.childCount) {
            val candidate = toParent.getChildAt(i)
            val candName = candidate.javaClass.simpleName
            Log.d(
                "RCTShareViewOverlay",
                "   → checking candidate[$i]=$candName, used=${used.contains(candidate)}"
            )

            if (!used.contains(candidate)) {
                // 1. Nếu đều là TextView (ReactTextView cũng tính)
                if ((fromChild is TextView && candidate is TextView) ||
                    (fromChild is ImageView && candidate is ImageView) ||
                    candidate::class.isInstance(fromChild)
                ) {
                    used.add(candidate)
                    Log.d("RCTShareViewOverlay", "   ✅ matched $fromName with $candName at index=$i")
                    return candidate
                }
            }
        }

        Log.d("RCTShareViewOverlay", "   ❌ no match found for $fromName")
        return null
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun deepCloneView(view: View): View {
        val clone: View = when (view) {
            is ViewGroup -> {
                val g = FrameLayout(context).apply {
                    background = cloneBackground(view)
                    setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, view.paddingBottom)
                    clipChildren = view.clipChildren
                    clipToPadding = view.clipToPadding
                }
                for (i in 0 until view.childCount) {
                    val child = view.getChildAt(i)
                    val childClone = deepCloneView(child).apply {
                        layoutParams = LayoutParams(
                            if (child.width > 0) child.width else LayoutParams.WRAP_CONTENT,
                            if (child.height > 0) child.height else LayoutParams.WRAP_CONTENT
                        )
                        x = child.left.toFloat()
                        y = child.top.toFloat()
                    }
                    g.addView(childClone)
                }
                g
            }

            is TextView -> {
                TextView(context).apply {
                    text = view.text
                    textSize = view.textSize / resources.displayMetrics.scaledDensity
                    setTextColor(view.currentTextColor)
                    typeface = view.typeface
                    gravity = view.gravity
                    letterSpacing = view.letterSpacing
                    isAllCaps = view.isAllCaps
                    setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, view.paddingBottom)
                    background = cloneBackground(view)
                }
            }

            is ImageView -> cloneImageView(view)

            else -> {
                View(context).apply {
                    background = cloneBackground(view)
                    setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, view.paddingBottom)
                }
            }
        }

        clone.layoutParams = LayoutParams(
            if (view.width > 0) view.width else LayoutParams.WRAP_CONTENT,
            if (view.height > 0) view.height else LayoutParams.WRAP_CONTENT
        )
        clone.rotation = view.rotation
        clone.rotationX = view.rotationX
        clone.rotationY = view.rotationY
        clone.scaleX = view.scaleX
        clone.scaleY = view.scaleY
        clone.pivotX = 0f
        clone.pivotY = 0f
        return clone
    }

    fun cloneImageView(from: ImageView): ImageView {
        val context = from.context
        val clone = ImageView(context)

        // copy layout params theo size gốc
        val lp = FrameLayout.LayoutParams(from.width, from.height)
        clone.layoutParams = lp

        // giữ nguyên các property quan trọng
        clone.scaleType = from.scaleType ?: ImageView.ScaleType.CENTER_CROP
        clone.setPadding(from.paddingLeft, from.paddingTop, from.paddingRight, from.paddingBottom)
        clone.background = from.background?.constantState?.newDrawable()?.mutate()

        // pivot center để animation scale/move mượt
        clone.pivotX = from.width / 2f
        clone.pivotY = from.height / 2f

        // cố lấy uri từ tag nếu có
        val tagUri = from.tag as? String
        if (!tagUri.isNullOrEmpty()) {
            Log.d("CloneImageView", "✅ Found uri tag: $tagUri, size=(${from.width}x${from.height})")
            clone.setImageURI(Uri.parse(tagUri))
        } else {
            // fallback: clone drawable snapshot
            val d = from.drawable?.constantState?.newDrawable()?.mutate() ?: from.drawable
            Log.d(
                "CloneImageView",
                "⚠️ No uri tag, fallback drawable. size=(${from.width}x${from.height})"
            )
            clone.setImageDrawable(d)
        }

        return clone
    }

    private fun cloneBackground(src: View): Drawable? {
        val bg = src.background ?: return null
        return bg.constantState?.newDrawable()?.mutate() ?: bg
    }

    /** Cleanup overlay khi unmount */
    fun didUnmount() {
        val root = parent as? ViewGroup
        root?.removeView(this)
        removeAllViews()
        overlayChild = null
    }

    private fun getTargetRoot(): ViewGroup? {
        val act: Activity? = when (val ctx = context) {
            is Activity -> ctx
            is ReactContext -> ctx.currentActivity
            else -> null
        }
        val content = act?.findViewById<ViewGroup>(android.R.id.content)
        return content ?: (act?.window?.decorView as? ViewGroup)
    }

    private fun ensureOnTop(root: ViewGroup, v: View) {
        v.elevation = DEFAULT_ELEV
        v.translationZ = DEFAULT_ELEV
        v.bringToFront()
        root.requestLayout()
        root.invalidate()
        Log.d("RCTShareViewOverlay", "Overlay ensured on top, childCount=${root.childCount}")
    }
}