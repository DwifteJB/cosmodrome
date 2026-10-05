package me.rmfosho.cosmodrome

import com.oguzhnatly.flutter_android_auto.FAAConstants
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(FAAConstants.flutterEngineId, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        CarChannel.attach(flutterEngine)
    }
}
