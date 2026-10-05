package me.rmfosho.cosmodrome

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.media.model.MediaPlaybackTemplate
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.Template
import com.oguzhnatly.flutter_android_auto.AndroidAutoService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object CarChannel {
    private const val NAME = "me.rmfosho.cosmodrome/car"

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNowPlaying" -> result.success(showNowPlaying())
                else -> result.notImplemented()
            }
        }
    }

    private fun showNowPlaying(): Boolean {
        val carContext = try {
            AndroidAutoService.session?.carContext
        } catch (_: IllegalStateException) {
            null
        } ?: return false
        if (carContext.carAppApiLevel < 8) return false
        val screens = carContext.getCarService(ScreenManager::class.java)
        if (screens.top is NowPlayingScreen) return true
        screens.push(NowPlayingScreen(carContext))
        return true
    }
}

class NowPlayingScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template = MediaPlaybackTemplate.Builder()
        .setHeader(Header.Builder().setStartHeaderAction(Action.BACK).build())
        .build()
}
