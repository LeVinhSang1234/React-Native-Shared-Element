package com.shareelement.view

import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.View
import android.view.ViewGroup
import androidx.annotation.RequiresApi
import androidx.core.view.isEmpty
import com.facebook.react.views.view.ReactViewGroup
import com.shareelement.view.helpers.RCTShareRouteRegistry
import com.shareelement.view.helpers.RCTShareViewOverlay
import com.facebook.react.bridge.ReactContext

class RCTShareView(context: Context) : ReactViewGroup(context) {

    var shareTagElement: String? = null
        set(value) {
            if (field == value) return
            val screenKey = RCTShareRouteRegistry.screenKeyOfView(this) ?: return

            field?.takeIf { it.isNotEmpty() }?.let {
                RCTShareRouteRegistry.unregisterView(this, it, screenKey)
            }
            value?.takeIf { it.isNotEmpty() }?.let {
                RCTShareRouteRegistry.registerView(this, it, screenKey)
            }

            field = value
        }

    var headerHeight: Double? = null
    var sharingAnimatedDuration: Double? = null
    var isBlurWindow: Boolean = false

    private val overlay: RCTShareViewOverlay = RCTShareViewOverlay(context)

    init {
        clipChildren = true
        alpha = 0f
    }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (isBlurWindow) {
            isBlurWindow = false
        }
        startSharedElementTransition()
    }

    fun initialize() {}

    @RequiresApi(Build.VERSION_CODES.P)
    fun prepareForRecycle() {
        performBackSharedElementIfPossible()
    }

    private fun cleanup() {
        val screenKey = RCTShareRouteRegistry.screenKeyOfView(this) ?: return
        shareTagElement?.let { RCTShareRouteRegistry.unregisterView(this, it, screenKey) }
        overlay.didUnmount()
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun performBackSharedElementIfPossible() {
        val tag = shareTagElement ?: return
        val target = RCTShareRouteRegistry.resolveShareTargetForView(this, tag)

        if (target == null || isEmpty()) {
            cleanup()
            return
        }
        val fromRect = rectForShare(this)
        val toRect = rectForShare(target)

        val duration = (sharingAnimatedDuration ?: 300.0).toLong()
        target.overlay.moveToOverlay(
            fromFrame = fromRect,
            toFrame = toRect,
            fromView = this,
            toView = target,
            duration = duration,
            onTarget = {
                target.alpha = 1f;
            },
            onCompleted = {
                cleanup()
            }
        )
    }


    @RequiresApi(Build.VERSION_CODES.P)
    private fun startSharedElementTransition() {
        val tag = shareTagElement ?: return
        val target = RCTShareRouteRegistry.resolveShareTargetForView(this, tag)

        if (target == null) {
            alpha = 1f
            return
        }
        post {
            postDelayed({
                val fromRect = rectForShare(target)
                val toRect = rectForShare(this)

                val duration = (sharingAnimatedDuration ?: 300.0).toLong()
                overlay.moveToOverlay(
                    fromFrame = fromRect,
                    toFrame = toRect,
                    fromView = target,
                    toView = this,
                    duration = duration,
                    onTarget = {
                        target.alpha = 1f;
                        alpha = 1f;
                    },
                    onCompleted = {}
                )
            }, 5)
        }
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