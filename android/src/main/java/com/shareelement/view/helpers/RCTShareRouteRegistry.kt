package com.shareelement.view.helpers

import android.view.View
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap
import com.shareelement.view.RCTShareView

object RCTShareRouteRegistry {
    // tag -> { screenKey -> [weak views] }
    private val tagScreens = ConcurrentHashMap<String, MutableMap<String, MutableList<WeakReference<RCTShareView>>>>()

    // tag -> { "screen": screenKey, "view": weak(view) }
    private val currentOwner = ConcurrentHashMap<String, Pair<String, WeakReference<RCTShareView>>>()

    // tag -> targetTag (nếu có)
    private val pendingTargetTag = ConcurrentHashMap<String, String>()

    // tag -> list of edges {from, to, ts}
    private val edges = ConcurrentHashMap<String, MutableList<Map<String, Any>>>()

    // recent screens (giữ gọn ~16)
    private val recentScreens = ArrayDeque<String>()

    fun registerView(view: RCTShareView, tag: String, screenKey: String) {
        if (tag.isEmpty() || screenKey.isEmpty()) return

        val screens = tagScreens.getOrPut(tag) { mutableMapOf() }
        val list = screens.getOrPut(screenKey) { mutableListOf() }

        val exists = list.any { it.get() == view }
        if (!exists) list.add(WeakReference(view))

        touchRecentScreen(screenKey)

        if (!currentOwner.containsKey(tag)) {
            currentOwner[tag] = screenKey to WeakReference(view)
        }
    }

    fun unregisterView(view: RCTShareView, tag: String, screenKey: String) {
        val list = tagScreens[tag]?.get(screenKey) ?: return
        val newList = list.filter { it.get() != null && it.get() != view }.toMutableList()
        if (newList.isNotEmpty()) {
            tagScreens[tag]?.set(screenKey, newList)
        } else {
            tagScreens[tag]?.remove(screenKey)
        }
    }

    fun setPendingTargetTag(tag: String, targetTag: String?) {
        if (tag.isEmpty()) return
        if (targetTag.isNullOrEmpty()) pendingTargetTag.remove(tag)
        else pendingTargetTag[tag] = targetTag
    }

    fun resolveShareTargetForView(view: RCTShareView, tag: String): RCTShareView? {
        if (tag.isEmpty()) return null
        val srcScreen = screenKeyOfView(view) ?: return null
        val expectTag = pendingTargetTag[tag] ?: tag
        val screens = tagScreens[expectTag] ?: return null

        // 1) Ưu tiên khác màn theo thứ tự recent
        for (sk in recentScreens.reversed()) {
            if (sk == srcScreen) continue
            val boxes = screens[sk] ?: continue
            for (b in boxes.asReversed()) {
                val candidate = b.get()
                if (candidate != null && candidate != view) {
                    return candidate
                }
            }
        }

        // 2) fallback: cùng màn
        val same = screens[srcScreen] ?: return null
        for (b in same.asReversed()) {
            val candidate = b.get()
            if (candidate != null && candidate != view) return candidate
        }

        return null
    }

    fun commitShare(fromView: RCTShareView, toView: RCTShareView, tag: String) {
        if (tag.isEmpty()) return

        val fromScreen = screenKeyOfView(fromView) ?: ""
        val toScreen = screenKeyOfView(toView) ?: ""

        currentOwner[tag] = toScreen to WeakReference(toView)

        val arr = edges.getOrPut(tag) { mutableListOf() }
        arr.add(
            mapOf(
                "from" to fromScreen,
                "to" to toScreen,
                "ts" to System.currentTimeMillis() / 1000.0
            )
        )

        if (toScreen.isNotEmpty()) touchRecentScreen(toScreen)
    }

    fun edgesForTag(tag: String): List<Map<String, Any>> {
        return edges[tag]?.toList() ?: emptyList()
    }

    fun screenKeyOfView(view: View): String? {
        // TODO: cần implement lấy "screenKey" giống iOS (nearest VC)
        // tạm: hashCode của context
        return view.context.hashCode().toString()
    }

    private fun touchRecentScreen(screenKey: String) {
        recentScreens.remove(screenKey)
        recentScreens.addLast(screenKey)
        if (recentScreens.size > 16) {
            recentScreens.removeFirst()
        }
    }
}