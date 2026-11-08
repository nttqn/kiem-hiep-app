package com.trungsmail.kiem_hiep

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferSixtyHz()
    }

    /**
     * The game steps at 60 per second. On 90/120 Hz screens (Xiaomi Pad 5,
     * many Redmi phones) drawing twice as many frames only heats the chip
     * until it slows down, and walking stutters (1.11.0). Ask for the 60 Hz
     * mode at the current resolution; phones without one keep their own.
     */
    private fun preferSixtyHz() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            @Suppress("DEPRECATION")
            val display: Display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) this.display else windowManager.defaultDisplay)
                ?: return
            val now = display.mode
            if (now.refreshRate <= 61f) return
            val sixty = display.supportedModes
                .filter {
                    it.physicalWidth == now.physicalWidth &&
                        it.physicalHeight == now.physicalHeight &&
                        it.refreshRate in 59f..61f
                }
                .firstOrNull() ?: return
            val attrs = window.attributes
            attrs.preferredDisplayModeId = sixty.modeId
            window.attributes = attrs
        } catch (e: Exception) {
            // Some vendors refuse; the default rate is fine then.
        }
    }
}
