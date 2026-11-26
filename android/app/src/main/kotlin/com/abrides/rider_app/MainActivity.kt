package com.abrides.rider_app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var rideActive = false
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.blackoriginx.torkkdriver/pip",
        )
        pipChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setRideActive") {
                rideActive = call.argument<Boolean>("active") == true
                updatePictureInPictureParams()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (
            rideActive &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(3, 4))
                    .build(),
            )
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("pictureInPictureChanged", isInPictureInPictureMode)
    }

    private fun updatePictureInPictureParams() {
        if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            return
        }
        setPictureInPictureParams(
            PictureInPictureParams.Builder()
                .setAspectRatio(Rational(3, 4))
                .setAutoEnterEnabled(rideActive)
                .build(),
        )
    }
}
