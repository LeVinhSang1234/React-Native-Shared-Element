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
        val used = mutableSetOf<View>()
        for (i in 0 until ghostView.childCount) {
            val ghostChild = ghostView.getChildAt(i)
            val toChild = findMatchingChild(ghostChild, toView, used)

            if (toChild == null) continue

            val startW = ghostChild.width
            val startH = ghostChild.height

            val endW = toChild.width
            val endH = toChild.height
            val endX = toChild.x
            val endY = toChild.y

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
                    ghostChild.animate()
                        .x(endX)
                        .y(endY)
                        .setDuration(duration)
                        .start()

                    ValueAnimator.ofFloat(0f, 1f).apply {
                        this.duration = duration
                        addUpdateListener { anim ->
                            val f = anim.animatedFraction
                            val newW = (startW + (endW - startW) * f).toInt()
                            val newH = (startH + (endH - startH) * f).toInt()
                            (ghostChild.layoutParams as FrameLayout.LayoutParams).apply {
                                width = newW
                                height = newH
                            }
                            ghostChild.requestLayout()
                        }
                        start()
                    }
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
        for (i in 0 until toParent.childCount) {
            val candidate = toParent.getChildAt(i)
            if (!used.contains(candidate)) {
                if ((fromChild is TextView && candidate is TextView) ||
                    (fromChild is ImageView && candidate is ImageView) ||
                    candidate::class.isInstance(fromChild)
                ) {
                    used.add(candidate)
                    return candidate
                }
            }
        }
        return null
    }

    fun deepCloneView(from: View): View {
        val clone: View = when (from) {
            is ImageView -> {
                val img = ImageView(from.context).apply {
                    layoutParams = LayoutParams(from.width, from.height)

                    val d = from.drawable?.constantState?.newDrawable()?.mutate() ?: from.drawable
                    setImageDrawable(d)

                    scaleType = from.scaleType

                    setPadding(from.paddingLeft, from.paddingTop, from.paddingRight, from.paddingBottom)
                    background = cloneBackground(from)

                    pivotX = from.width / 2f
                    pivotY = from.height / 2f
                }
                img
            }

            is TextView -> {
                val tv = TextView(from.context)
                tv.layoutParams = LayoutParams(from.width, from.height)
                tv.text = from.text
                tv.setTextColor(from.currentTextColor)
                tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, from.textSize)
                tv.typeface = from.typeface
                tv.gravity = from.gravity
                tv.letterSpacing = from.letterSpacing

                tv.setPadding(from.paddingLeft, from.paddingTop, from.paddingRight, from.paddingBottom)
                tv.background = cloneBackground(from)
                tv.pivotX = from.width / 2f
                tv.pivotY = from.height / 2f
                tv
            }

            is ViewGroup -> {
                val group = FrameLayout(from.context)
                group.layoutParams = FrameLayout.LayoutParams(from.width, from.height)
                group.setPadding(from.paddingLeft, from.paddingTop, from.paddingRight, from.paddingBottom)
                group.background = cloneBackground(from)
                group.clipToPadding = from.clipToPadding
                group.clipChildren = from.clipChildren

                for (i in 0 until from.childCount) {
                    val childClone = deepCloneView(from.getChildAt(i))
                    val lp = LayoutParams(from.getChildAt(i).width, from.getChildAt(i).height)
                    lp.leftMargin = from.getChildAt(i).left
                    lp.topMargin = from.getChildAt(i).top
                    childClone.layoutParams = lp
                    group.addView(childClone)
                }

                group.pivotX = from.width / 2f
                group.pivotY = from.height / 2f
                group
            }

            else -> {
                val v = View(from.context)
                v.layoutParams = LayoutParams(from.width, from.height)
                v.setPadding(from.paddingLeft, from.paddingTop, from.paddingRight, from.paddingBottom)
                v.background = cloneBackground(from)
                v.pivotX = from.width / 2f
                v.pivotY = from.height / 2f
                v
            }
        }

        // copy common props
        clone.alpha = from.alpha
        clone.rotation = from.rotation
        clone.rotationX = from.rotationX
        clone.rotationY = from.rotationY
        clone.scaleX = from.scaleX
        clone.scaleY = from.scaleY

        // force measure/layout
        val wSpec = MeasureSpec.makeMeasureSpec(from.width, MeasureSpec.EXACTLY)
        val hSpec = MeasureSpec.makeMeasureSpec(from.height, MeasureSpec.EXACTLY)
        clone.measure(wSpec, hSpec)
        clone.layout(from.left, from.top, from.right, from.bottom)
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
    }
}