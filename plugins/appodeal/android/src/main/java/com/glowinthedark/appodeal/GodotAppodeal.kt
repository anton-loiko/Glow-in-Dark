package com.glowinthedark.appodeal

import com.appodeal.ads.Appodeal
import com.appodeal.ads.RewardedVideoCallbacks
import com.appodeal.ads.initializing.ApdInitializationCallback
import com.appodeal.ads.initializing.ApdInitializationError
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Тонкая обёртка Appodeal для Glow in the Dark (D17): только Rewarded Video.
 * Контракт — docs/research/appodeal_wrapper.md; GDScript-сторона — src/services/ads/AppodealBackend.gd.
 * Согласия (GDPR/UMP) Appodeal SDK 4.x запрашивает сам во время initialize(), до загрузки рекламы.
 */
class GodotAppodeal(godot: Godot) : GodotPlugin(godot) {

    private var initialized = false

    override fun getPluginName(): String = "GodotAppodeal"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("initialized", String::class.java),
        SignalInfo("rewarded_loaded"),
        SignalInfo("rewarded_load_failed"),
        SignalInfo("rewarded_shown"),
        SignalInfo("rewarded_show_failed"),
        SignalInfo("rewarded_finished", Double::class.javaObjectType, String::class.java),
        SignalInfo("rewarded_closed", Boolean::class.javaObjectType),
    )

    @UsedByGodot
    fun initialize(appKey: String, testing: Boolean) {
        val activity = activity ?: return
        if (initialized || appKey.isEmpty()) {
            if (appKey.isEmpty()) emitSignal("initialized", "empty_app_key")
            return
        }
        initialized = true
        Appodeal.setTesting(testing)
        Appodeal.setRewardedVideoCallbacks(object : RewardedVideoCallbacks {
            override fun onRewardedVideoLoaded(isPrecache: Boolean) = emitSignal("rewarded_loaded")
            override fun onRewardedVideoFailedToLoad() = emitSignal("rewarded_load_failed")
            override fun onRewardedVideoShown() = emitSignal("rewarded_shown")
            override fun onRewardedVideoShowFailed() = emitSignal("rewarded_show_failed")
            override fun onRewardedVideoFinished(amount: Double, currency: String) =
                emitSignal("rewarded_finished", amount, currency)
            override fun onRewardedVideoClosed(finished: Boolean) = emitSignal("rewarded_closed", finished)
            override fun onRewardedVideoExpired() = emitSignal("rewarded_load_failed")
            override fun onRewardedVideoClicked() {}
        })
        Appodeal.initialize(activity, appKey, Appodeal.REWARDED_VIDEO, object : ApdInitializationCallback {
            override fun onInitializationFinished(errors: List<ApdInitializationError>?) {
                emitSignal("initialized", errors?.joinToString("|") { it.message ?: "" } ?: "")
            }
        })
    }

    @UsedByGodot
    fun is_rewarded_loaded(): Boolean = initialized && Appodeal.isLoaded(Appodeal.REWARDED_VIDEO)

    @UsedByGodot
    fun show_rewarded(placement: String) {
        val activity = activity ?: return
        activity.runOnUiThread {
            if (!Appodeal.show(activity, Appodeal.REWARDED_VIDEO, placement)) {
                emitSignal("rewarded_show_failed")
            }
        }
    }
}
