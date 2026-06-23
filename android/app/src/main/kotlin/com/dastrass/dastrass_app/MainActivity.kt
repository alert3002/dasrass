package com.dastrass.dastrass_app

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun provideFlutterEngine(context: Context): FlutterEngine? {
    return FlutterEngineCache.getInstance().get(DastrassApplication.ENGINE_ID)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THEME_CHANNEL)
      .setMethodCallHandler { call, result ->
        if (call.method == "setThemePref") {
          val value = call.arguments as? String ?: "system"
          nativeThemePrefs(this).edit().putString(THEME_KEY, value).apply()
          result.success(null)
        } else {
          result.notImplemented()
        }
      }
  }

  private fun nativeThemePrefs(context: Context): SharedPreferences =
    context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)

  companion object {
    private const val THEME_CHANNEL = "com.dastrass/theme"
    private const val NATIVE_PREFS = "dastrass_native_prefs"
    private const val THEME_KEY = "theme"
  }
}
