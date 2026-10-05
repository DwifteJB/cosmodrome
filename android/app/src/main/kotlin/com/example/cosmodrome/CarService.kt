package me.rmfosho.cosmodrome

import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import com.oguzhnatly.flutter_android_auto.AndroidAutoService
import com.oguzhnatly.flutter_android_auto.AndroidAutoSession
import com.oguzhnatly.flutter_android_auto.FAAConstants
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngineCache

class CarService : CarAppService() {
    override fun onCreate() {
        super.onCreate()
        val engine = AudioServicePlugin.getFlutterEngine(this)
        FlutterEngineCache.getInstance().put(FAAConstants.flutterEngineId, engine)
        CarChannel.attach(engine)
    }

    override fun createHostValidator(): HostValidator {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        }
        return HostValidator.Builder(applicationContext)
            .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
            .build()
    }

    override fun onCreateSession(): Session {
        val session = AndroidAutoSession()
        AndroidAutoService.session = session
        return session
    }
}
