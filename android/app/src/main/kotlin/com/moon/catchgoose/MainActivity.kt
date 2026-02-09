package com.moon.catchgoose

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterShellArgs

class MainActivity : FlutterActivity() {
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val shellArgs = FlutterShellArgs.fromIntent(intent)
        shellArgs.add("--enable-flutter-gpu")
        shellArgs.add("--impeller-backend=opengles")
        return shellArgs
    }
}
