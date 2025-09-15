package com.shareelement.view

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class RCTShareViewPackage : ReactPackage {
    override fun createViewManagers(reactContext: ReactApplicationContext)
            = listOf<ViewManager<*, *>>(RCTShareViewManager())

    override fun createNativeModules(reactContext: ReactApplicationContext)
            = emptyList<NativeModule>()
}