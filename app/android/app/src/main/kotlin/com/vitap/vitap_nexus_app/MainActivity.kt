package com.vitap.vitap_nexus_app

import android.app.KeyguardManager
import android.content.Context
import android.content.DialogInterface
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vitap.vitap_nexus_app/biometrics"
    private val WIDGET_CHANNEL = "com.vitap.vitap_nexus_app/widgets"
    private var cancellationSignal: CancellationSignal? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    WidgetUpdater.updateAll(applicationContext)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBiometricAvailable" -> {
                        result.success(checkBiometricAvailable())
                    }
                    "authenticate" -> {
                        val title = call.argument<String>("title") ?: "Biometric Authentication"
                        val subtitle = call.argument<String>("subtitle")
                            ?: "Unlock VITAP Nexus with your fingerprint or face"
                        authenticateUser(title, subtitle, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkBiometricAvailable(): Boolean {
        return try {
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val bm = getSystemService(BiometricManager::class.java)
                val canAuth = bm?.canAuthenticate()
                canAuth == BiometricManager.BIOMETRIC_SUCCESS || (keyguard?.isDeviceSecure == true)
            } else {
                keyguard?.isDeviceSecure == true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun authenticateUser(
        title: String,
        subtitle: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            result.success(keyguard?.isDeviceSecure == true)
            return
        }

        try {
            var completed = false
            fun finishOnce(success: Boolean) {
                if (!completed) {
                    completed = true
                    runOnUiThread { result.success(success) }
                }
            }

            val builder = BiometricPrompt.Builder(this)
                .setTitle(title)
                .setSubtitle(subtitle)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG or
                        BiometricManager.Authenticators.BIOMETRIC_WEAK or
                        BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
            } else {
                builder.setNegativeButton(
                    "Use App Password",
                    mainExecutor,
                    DialogInterface.OnClickListener { _, _ -> finishOnce(false) }
                )
            }

            val prompt = builder.build()
            val signal = CancellationSignal()
            cancellationSignal = signal

            prompt.authenticate(
                signal,
                mainExecutor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authResult: BiometricPrompt.AuthenticationResult?
                    ) {
                        super.onAuthenticationSucceeded(authResult)
                        finishOnce(true)
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence?
                    ) {
                        super.onAuthenticationError(errorCode, errString)
                        finishOnce(false)
                    }

                    override fun onAuthenticationFailed() {
                        super.onAuthenticationFailed()
                    }
                }
            )
        } catch (e: Exception) {
            result.success(false)
        }
    }
}
