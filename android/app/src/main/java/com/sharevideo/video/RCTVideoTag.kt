// Đặt package khớp với RCTVideoView.kt
package com.sharevideo.video

import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

/**
 * Registry static để quản lý nhiều RCTVideoView theo cùng một tag (giống iOS).
 * - registerView(view, tag)
 * - removeView(view, tag)
 * - getOtherViewForTag(view, tag): trả về view khác cùng tag (ưu tiên view đăng ký sau)
 */
object RCTVideoTag {
    private val tagToViewsMap = ConcurrentHashMap<String, MutableList<WeakReference<RCTVideoView>>>()

    @JvmStatic
    fun registerView(view: RCTVideoView?, tag: String?) {
        if (view == null || tag.isNullOrBlank()) return
        synchronized(this) {
            val list = tagToViewsMap.getOrPut(tag) { mutableListOf() }
            list.removeAll { it.get() == null }
            if (list.none { it.get() === view }) list.add(WeakReference(view))
        }
    }

    @JvmStatic
    fun removeView(view: RCTVideoView?, tag: String?) {
        if (tag.isNullOrBlank()) return
        synchronized(this) {
            val list = tagToViewsMap[tag] ?: return
            if (view != null) list.removeAll { it.get() == null || it.get() === view }
            else list.removeAll { it.get() == null }
            if (list.isEmpty()) tagToViewsMap.remove(tag)
        }
    }

    @JvmStatic
    fun getOtherViewForTag(view: RCTVideoView?, tag: String?): RCTVideoView? {
        if (tag.isNullOrBlank()) return null
        synchronized(this) {
            val list = tagToViewsMap[tag] ?: return null
            list.removeAll { it.get() == null }
            for (i in list.size - 1 downTo 0) {
                val v = list[i].get()
                if (v != null && v !== view) return v
            }
            return null
        }
    }
}