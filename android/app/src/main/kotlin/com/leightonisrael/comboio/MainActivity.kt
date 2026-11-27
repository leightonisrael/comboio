package com.leightonisrael.comboio

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "comboio/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRoute" -> result.success(currentRoute())
                    "bindWifi" -> {
                        bindWifi()
                        result.success(null)
                    }
                    "openSettings" -> {
                        openSettings(call.argument<String>("kind") ?: "app")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private var wifiCallback: ConnectivityManager.NetworkCallback? = null

    /**
     * Prende o trafego do app ao Wi-Fi enquanto ele existir. Em um Wi-Fi sem
     * internet (o roteador de outro celular) o Android manda o trafego pelos
     * dados moveis, e os outros celulares da sala ficam inalcancaveis.
     */
    private fun bindWifi() {
        if (wifiCallback != null) return
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    cm.bindProcessToNetwork(network)
                }

                override fun onLost(network: Network) {
                    if (cm.boundNetworkForProcess == network) cm.bindProcessToNetwork(null)
                }
            }
            cm.requestNetwork(request, callback)
            wifiCallback = callback
        } catch (_: Exception) {
            // Sem a permissao ou sem Wi-Fi: segue com a rede padrao.
        }
    }

    override fun onDestroy() {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            wifiCallback?.let { cm.unregisterNetworkCallback(it) }
            cm.bindProcessToNetwork(null)
        } catch (_: Exception) {
        }
        wifiCallback = null
        super.onDestroy()
    }

    /** Procura um headset Bluetooth capaz de voz (HFP/SCO ou LE Audio). */
    private fun currentRoute(): Map<String, Any> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val voiceTypes = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
        )
        val headset = am.getDevices(AudioManager.GET_DEVICES_INPUTS or AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type in voiceTypes }
        return mapOf(
            "bluetooth" to (headset != null),
            "name" to (headset?.productName?.toString() ?: ""),
        )
    }

    private fun openSettings(kind: String) {
        val intents = when (kind) {
            "bluetooth" -> listOf(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
            "wifi" -> listOf(Intent(Settings.ACTION_WIFI_SETTINGS))
            "hotspot" -> listOf(
                Intent().setClassName("com.android.settings", "com.android.settings.TetherSettings"),
                Intent(Settings.ACTION_WIRELESS_SETTINGS),
            )
            else -> listOf(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
            )
        }
        for (intent in intents) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: Exception) {
                // Tenta a próxima opção.
            }
        }
    }
}
