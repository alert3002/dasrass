package com.dastrass.dastrass_app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

class DastrassApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    val engine = FlutterEngine(this)
    GeneratedPluginRegistrant.registerWith(engine)
    engine.dartExecutor.executeDartEntrypoint(
      DartExecutor.DartEntrypoint.createDefault(),
    )
    FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
  }

  companion object {
    const val ENGINE_ID = "dastrass_main_engine"
  }
}
