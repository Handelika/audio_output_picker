package com.handelika.audiopicker

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.bluetooth.BluetoothDevice
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** AudioOutputPickerPlugin */
class AudioOutputPickerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private val tag = "AudioOutputPicker"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingBluetoothPermissionResult: Result? = null
    private var pendingMicPermissionResult: Result? = null
    private var selectedOutputDeviceId: String? = null
    private var selectedInputDeviceId: String? = null
    private var eventSink: EventChannel.EventSink? = null

    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var broadcastReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    companion object {
        private const val REQUEST_CODE_BLUETOOTH_CONNECT = 1001
        private const val REQUEST_CODE_RECORD_AUDIO = 1002
    }

    /**
     * Thread-safe Result wrapper to prevent "Reply already submitted" crashes
     * and guarantee single-reply execution on the main looper.
     */
    private class SafeResult(private val originalResult: Result, private val mainHandler: Handler) : Result {
        private val replied = AtomicBoolean(false)

        override fun success(result: Any?) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post {
                    try {
                        originalResult.success(result)
                    } catch (t: Throwable) {
                        Log.e("AudioOutputPicker", "Failed to send success result", t)
                    }
                }
            }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post {
                    try {
                        originalResult.error(errorCode, errorMessage, errorDetails)
                    } catch (t: Throwable) {
                        Log.e("AudioOutputPicker", "Failed to send error result", t)
                    }
                }
            }
        }

        override fun notImplemented() {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post {
                    try {
                        originalResult.notImplemented()
                    } catch (t: Throwable) {
                        Log.e("AudioOutputPicker", "Failed to send notImplemented result", t)
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        try {
            context = flutterPluginBinding.applicationContext
            val mc = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_output_picker")
            mc.setMethodCallHandler(this)
            methodChannel = mc

            val ec = EventChannel(flutterPluginBinding.binaryMessenger, "audio_output_picker/events")
            ec.setStreamHandler(this)
            eventChannel = ec
        } catch (t: Throwable) {
            Log.e(tag, "Error during onAttachedToEngine", t)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        registerNativeDeviceListeners()
    }

    override fun onCancel(arguments: Any?) {
        unregisterNativeDeviceListeners()
        this.eventSink = null
    }

    private fun notifyDeviceChanged() {
        mainHandler.post {
            try {
                eventSink?.success(mapOf("event" to "devices_changed"))
            } catch (t: Throwable) {
                Log.w(tag, "Failed to emit devices_changed event", t)
            }
        }
        // Send a follow-up event after a short delay to ensure OS routing has fully settled
        mainHandler.postDelayed({
            try {
                eventSink?.success(mapOf("event" to "devices_changed_settled"))
            } catch (t: Throwable) {
                Log.w(tag, "Failed to emit devices_changed_settled event", t)
            }
        }, 200)
    }

    private fun registerNativeDeviceListeners() {
        val currentContext = context ?: return
        val audioManager = getAudioManager()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && audioManager != null) {
                audioDeviceCallback = object : AudioDeviceCallback() {
                    override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                        selectedOutputDeviceId = null
                        selectedInputDeviceId = null
                        notifyDeviceChanged()
                    }

                    override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                        selectedOutputDeviceId = null
                        selectedInputDeviceId = null
                        notifyDeviceChanged()
                    }
                }
                audioManager.registerAudioDeviceCallback(audioDeviceCallback, mainHandler)
            }
        } catch (t: Throwable) {
            Log.w(tag, "Failed to register audioDeviceCallback", t)
        }

        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_HEADSET_PLUG)
                addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED")
                addAction("android.media.action.HDMI_AUDIO_PLUG_STATUS")
            }

            broadcastReceiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    try {
                        val action = intent?.action
                        if (action == Intent.ACTION_HEADSET_PLUG ||
                            action == BluetoothDevice.ACTION_ACL_CONNECTED ||
                            action == BluetoothDevice.ACTION_ACL_DISCONNECTED ||
                            action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                            selectedOutputDeviceId = null
                            selectedInputDeviceId = null
                        }
                        notifyDeviceChanged()
                    } catch (t: Throwable) {
                        Log.w(tag, "Error in broadcastReceiver.onReceive", t)
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.registerReceiver(
                    currentContext,
                    broadcastReceiver!!,
                    filter,
                    ContextCompat.RECEIVER_EXPORTED
                )
            } else {
                currentContext.registerReceiver(broadcastReceiver, filter)
            }
        } catch (t: Throwable) {
            Log.w(tag, "Failed to register broadcastReceiver", t)
        }
    }

    private fun unregisterNativeDeviceListeners() {
        val currentContext = context
        val audioManager = getAudioManager()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && audioDeviceCallback != null && audioManager != null) {
                audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
                audioDeviceCallback = null
            }
        } catch (t: Throwable) {
            Log.w(tag, "Failed to unregister audioDeviceCallback", t)
        }

        if (broadcastReceiver != null && currentContext != null) {
            try {
                currentContext.unregisterReceiver(broadcastReceiver)
            } catch (t: Throwable) {
                Log.w(tag, "Failed to unregister broadcastReceiver", t)
            }
            broadcastReceiver = null
        }
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        val safeResult = SafeResult(result, mainHandler)

        try {
            when (call.method) {
                "getPlatformVersion" -> {
                    safeResult.success("Android ${Build.VERSION.RELEASE}")
                }
                "checkBluetoothPermission", "checkPermission" -> {
                    backgroundExecutor.execute {
                        try {
                            val hasPermission = hasBluetoothPermission()
                            safeResult.success(hasPermission)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error checking bluetooth permission", t)
                            safeResult.success(false)
                        }
                    }
                }
                "requestBluetoothPermission", "requestPermission" -> {
                    requestBluetoothPermission(safeResult)
                }
                "checkMicrophonePermission" -> {
                    backgroundExecutor.execute {
                        try {
                            val hasPermission = hasMicrophonePermission()
                            safeResult.success(hasPermission)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error checking microphone permission", t)
                            safeResult.success(false)
                        }
                    }
                }
                "requestMicrophonePermission" -> {
                    requestMicrophonePermission(safeResult)
                }
                "getAvailableAudioOutputs" -> {
                    backgroundExecutor.execute {
                        try {
                            val outputs = getAvailableAudioOutputs()
                            safeResult.success(outputs)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error getting audio outputs", t)
                            safeResult.success(emptyList<Map<String, Any>>())
                        }
                    }
                }
                "selectAudioOutput" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        backgroundExecutor.execute {
                            try {
                                val success = selectAudioOutput(deviceId)
                                safeResult.success(success)
                            } catch (t: Throwable) {
                                Log.e(tag, "Error selecting audio output: $deviceId", t)
                                safeResult.success(false)
                            }
                        }
                    } else {
                        safeResult.error("INVALID_ARGUMENT", "deviceId is required", null)
                    }
                }
                "getCurrentAudioOutput" -> {
                    backgroundExecutor.execute {
                        try {
                            val current = getCurrentAudioOutput()
                            safeResult.success(current)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error getting current audio output", t)
                            safeResult.success(null)
                        }
                    }
                }
                "getAvailableMicrophones" -> {
                    backgroundExecutor.execute {
                        try {
                            val mics = getAvailableMicrophones()
                            safeResult.success(mics)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error getting available microphones", t)
                            safeResult.success(emptyList<Map<String, Any>>())
                        }
                    }
                }
                "selectMicrophone" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        backgroundExecutor.execute {
                            try {
                                val success = selectMicrophone(deviceId)
                                safeResult.success(success)
                            } catch (t: Throwable) {
                                Log.e(tag, "Error selecting microphone: $deviceId", t)
                                safeResult.success(false)
                            }
                        }
                    } else {
                        safeResult.error("INVALID_ARGUMENT", "deviceId is required", null)
                    }
                }
                "getCurrentMicrophone" -> {
                    backgroundExecutor.execute {
                        try {
                            val current = getCurrentMicrophone()
                            safeResult.success(current)
                        } catch (t: Throwable) {
                            Log.e(tag, "Error getting current microphone", t)
                            safeResult.success(null)
                        }
                    }
                }
                else -> {
                    safeResult.notImplemented()
                }
            }
        } catch (t: Throwable) {
            Log.e(tag, "Unexpected error in onMethodCall: ${call.method}", t)
            safeResult.error("NATIVE_ERROR", t.localizedMessage ?: "Unexpected native exception", null)
        }
    }

    private fun getAudioManager(): AudioManager? {
        return try {
            context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        } catch (t: Throwable) {
            Log.w(tag, "Failed to get AudioManager", t)
            null
        }
    }

    // ==========================================
    // Audio Outputs
    // ==========================================

    private fun getOutputTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "receiver"
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wiredHeadphones"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_HEARING_AID -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_HDMI_EARC -> "hdmi"
            else -> "unknown"
        }
    }

    private fun isPluggedOrConnectedOutput(device: AudioDeviceInfo): Boolean {
        if (!device.isSink) return false

        return when (device.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_HEARING_AID,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY,
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_HDMI_EARC,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
            AudioDeviceInfo.TYPE_AUX_LINE,
            AudioDeviceInfo.TYPE_DOCK -> true
            else -> false
        }
    }

    private fun getOutputPriority(type: Int): Int {
        return when (type) {
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> 100
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> 90
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_HEARING_AID -> 80
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
            AudioDeviceInfo.TYPE_AUX_LINE,
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_HDMI_EARC,
            AudioDeviceInfo.TYPE_DOCK -> 70
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> 10
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> 5
            else -> 0
        }
    }

    private fun determineActiveOutputDeviceId(
        audioManager: AudioManager,
        devices: List<AudioDeviceInfo>
    ): String? {
        try {
            if (devices.isEmpty()) return null

            // 1. If user explicitly selected a device that is still connected
            if (selectedOutputDeviceId != null) {
                val matching = devices.firstOrNull { it.id.toString() == selectedOutputDeviceId }
                if (matching != null) {
                    return matching.id.toString()
                } else {
                    selectedOutputDeviceId = null
                }
            }

            // 2. Check communicationDevice on Android 12+ (API 31+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val commDevice = audioManager.communicationDevice
                    if (commDevice != null) {
                        val matchingComm = devices.firstOrNull { it.id == commDevice.id }
                        if (matchingComm != null) {
                            return matchingComm.id.toString()
                        }
                    }
                } catch (t: Throwable) {
                    Log.w(tag, "Error accessing communicationDevice", t)
                }
            }

            // 3. If speakerphone is forced on
            try {
                if (audioManager.isSpeakerphoneOn) {
                    val speakerDevice = devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                    if (speakerDevice != null) {
                        return speakerDevice.id.toString()
                    }
                }
            } catch (t: Throwable) {
                Log.w(tag, "Error checking isSpeakerphoneOn", t)
            }

            // 4. Default OS routing hierarchy: highest priority plugged/connected device is active
            val bestDevice = devices.maxByOrNull { getOutputPriority(it.type) }
            return bestDevice?.id?.toString()
        } catch (t: Throwable) {
            Log.e(tag, "Error in determineActiveOutputDeviceId", t)
            return null
        }
    }

    private fun getAvailableAudioOutputs(): List<Map<String, Any>> {
        val audioManager = getAudioManager() ?: return emptyList()
        val devicesList = mutableListOf<Map<String, Any>>()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val rawDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val filteredDevices = rawDevices.filter { isPluggedOrConnectedOutput(it) }
                val activeDeviceId = determineActiveOutputDeviceId(audioManager, filteredDevices)

                for (device in filteredDevices) {
                    val deviceId = device.id.toString()
                    val rawName = try { device.productName?.toString() ?: "" } catch (_: Throwable) { "" }
                    val typeName = getOutputTypeName(device.type)
                    val displayName = if (rawName.isNotBlank() && rawName != "null") rawName else when (device.type) {
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Speaker"
                        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Earpiece"
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                        AudioDeviceInfo.TYPE_BLE_HEADSET,
                        AudioDeviceInfo.TYPE_BLE_SPEAKER -> "Bluetooth Audio"
                        AudioDeviceInfo.TYPE_USB_DEVICE,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB Audio"
                        AudioDeviceInfo.TYPE_HDMI,
                        AudioDeviceInfo.TYPE_HDMI_ARC,
                        AudioDeviceInfo.TYPE_HDMI_EARC -> "HDMI Output"
                        else -> "Audio Output"
                    }

                    val isCurrent = (activeDeviceId != null && deviceId == activeDeviceId)

                    devicesList.add(
                        mapOf(
                            "id" to deviceId,
                            "name" to displayName,
                            "type" to typeName,
                            "isSelected" to isCurrent
                        )
                    )
                }
            }
        } catch (t: Throwable) {
            Log.e(tag, "Error querying getDevices(OUTPUTS)", t)
        }

        // Fallback: If no device is marked selected, select speaker or first device
        if (devicesList.isNotEmpty() && devicesList.none { it["isSelected"] == true }) {
            val updated = devicesList.toMutableList()
            val speakerIndex = updated.indexOfFirst { (it["type"] as? String) == "speaker" }
            val indexToSelect = if (speakerIndex >= 0) speakerIndex else 0
            val targetMap = updated[indexToSelect].toMutableMap()
            targetMap["isSelected"] = true
            updated[indexToSelect] = targetMap
            return updated
        }

        if (devicesList.isEmpty()) {
            devicesList.add(
                mapOf(
                    "id" to "builtin_speaker",
                    "name" to "Built-in Speaker",
                    "type" to "speaker",
                    "isSelected" to true
                )
            )
        }

        return devicesList
    }

    private fun selectAudioOutput(deviceId: String): Boolean {
        val audioManager = getAudioManager() ?: return false
        selectedOutputDeviceId = deviceId

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val target = devices.firstOrNull { it.id.toString() == deviceId }

                if (target != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            if (target.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                                audioManager.clearCommunicationDevice()
                                audioManager.isSpeakerphoneOn = true
                            } else {
                                audioManager.setCommunicationDevice(target)
                                audioManager.isSpeakerphoneOn = false
                            }
                        } catch (t: Throwable) {
                            Log.w(tag, "Error setting communication device", t)
                        }
                    } else {
                        try {
                            if (target.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                                audioManager.isSpeakerphoneOn = true
                            } else {
                                audioManager.isSpeakerphoneOn = false
                            }
                        } catch (t: Throwable) {
                            Log.w(tag, "Error toggling speakerphone", t)
                        }
                    }
                    notifyDeviceChanged()
                    return true
                }
            }

            if (deviceId.contains("speaker", ignoreCase = true)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        audioManager.clearCommunicationDevice()
                    } catch (t: Throwable) {
                        Log.w(tag, "Error clearing communication device", t)
                    }
                }
                try {
                    audioManager.isSpeakerphoneOn = true
                } catch (t: Throwable) {
                    Log.w(tag, "Error setting isSpeakerphoneOn", t)
                }
            } else {
                try {
                    audioManager.isSpeakerphoneOn = false
                } catch (t: Throwable) {
                    Log.w(tag, "Error clearing isSpeakerphoneOn", t)
                }
            }
            notifyDeviceChanged()
            return true
        } catch (t: Throwable) {
            Log.e(tag, "Error selecting audio output $deviceId", t)
            notifyDeviceChanged()
            return false
        }
    }

    private fun getCurrentAudioOutput(): Map<String, Any>? {
        val outputs = getAvailableAudioOutputs()
        return outputs.firstOrNull { it["isSelected"] == true } ?: outputs.firstOrNull()
    }

    // ==========================================
    // Audio Inputs / Microphones
    // ==========================================

    private fun getInputTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_MIC -> "builtInMic"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadsetMic"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_HEARING_AID -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
            else -> "unknown"
        }
    }

    private fun getInputPriority(type: Int): Int {
        return when (type) {
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> 100
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> 90
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_HEARING_AID -> 80
            AudioDeviceInfo.TYPE_BUILTIN_MIC -> 10
            else -> 0
        }
    }

    private fun determineActiveInputDeviceId(
        audioManager: AudioManager,
        devices: List<AudioDeviceInfo>
    ): String? {
        try {
            if (devices.isEmpty()) return null

            if (selectedInputDeviceId != null) {
                val matching = devices.firstOrNull { it.id.toString() == selectedInputDeviceId }
                if (matching != null) {
                    return matching.id.toString()
                } else {
                    selectedInputDeviceId = null
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val commDevice = audioManager.communicationDevice
                    if (commDevice != null && commDevice.isSource) {
                        val matchingComm = devices.firstOrNull { it.id == commDevice.id }
                        if (matchingComm != null) {
                            return matchingComm.id.toString()
                        }
                    }
                } catch (t: Throwable) {
                    Log.w(tag, "Error querying communicationDevice for input", t)
                }
            }

            val bestDevice = devices.maxByOrNull { getInputPriority(it.type) }
            return bestDevice?.id?.toString()
        } catch (t: Throwable) {
            Log.e(tag, "Error in determineActiveInputDeviceId", t)
            return null
        }
    }

    private fun getAvailableMicrophones(): List<Map<String, Any>> {
        val audioManager = getAudioManager() ?: return emptyList()
        val micList = mutableListOf<Map<String, Any>>()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val rawDevices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                val filteredDevices = rawDevices.filter { it.isSource }
                val activeDeviceId = determineActiveInputDeviceId(audioManager, filteredDevices)

                for (device in filteredDevices) {
                    val deviceId = device.id.toString()
                    val rawName = try { device.productName?.toString() ?: "" } catch (_: Throwable) { "" }
                    val typeName = getInputTypeName(device.type)
                    val displayName = if (rawName.isNotBlank() && rawName != "null") rawName else when (device.type) {
                        AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Built-in Microphone"
                        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Headset Microphone"
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                        AudioDeviceInfo.TYPE_BLE_HEADSET -> "Bluetooth Microphone"
                        AudioDeviceInfo.TYPE_USB_DEVICE,
                        AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Microphone"
                        else -> "Microphone"
                    }

                    val isCurrent = (activeDeviceId != null && deviceId == activeDeviceId)

                    micList.add(
                        mapOf(
                            "id" to deviceId,
                            "name" to displayName,
                            "type" to typeName,
                            "isSelected" to isCurrent
                        )
                    )
                }
            }
        } catch (t: Throwable) {
            Log.e(tag, "Error querying getDevices(INPUTS)", t)
        }

        if (micList.isNotEmpty() && micList.none { it["isSelected"] == true }) {
            val updated = micList.toMutableList()
            val builtInIndex = updated.indexOfFirst { (it["type"] as? String) == "builtInMic" }
            val indexToSelect = if (builtInIndex >= 0) builtInIndex else 0
            val targetMap = updated[indexToSelect].toMutableMap()
            targetMap["isSelected"] = true
            updated[indexToSelect] = targetMap
            return updated
        }

        if (micList.isEmpty()) {
            micList.add(
                mapOf(
                    "id" to "builtin_mic",
                    "name" to "Built-in Microphone",
                    "type" to "builtInMic",
                    "isSelected" to true
                )
            )
        }

        return micList
    }

    private fun selectMicrophone(deviceId: String): Boolean {
        val audioManager = getAudioManager() ?: return false
        selectedInputDeviceId = deviceId

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                val target = devices.firstOrNull { it.id.toString() == deviceId }

                if (target != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            audioManager.setCommunicationDevice(target)
                        } catch (t: Throwable) {
                            Log.w(tag, "Error setting communication device for mic", t)
                        }
                    }
                    notifyDeviceChanged()
                    return true
                }
            }
            notifyDeviceChanged()
            return true
        } catch (t: Throwable) {
            Log.e(tag, "Error selecting microphone $deviceId", t)
            notifyDeviceChanged()
            return false
        }
    }

    private fun getCurrentMicrophone(): Map<String, Any>? {
        val mics = getAvailableMicrophones()
        return mics.firstOrNull { it["isSelected"] == true } ?: mics.firstOrNull()
    }

    // ==========================================
    // Permissions
    // ==========================================

    private fun hasBluetoothPermission(): Boolean {
        val currentContext = context ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                ContextCompat.checkSelfPermission(
                    currentContext,
                    Manifest.permission.BLUETOOTH_CONNECT
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        } catch (t: Throwable) {
            Log.w(tag, "Error checking bluetooth permission", t)
            false
        }
    }

    private fun requestBluetoothPermission(result: Result) {
        try {
            if (hasBluetoothPermission()) {
                result.success(true)
                return
            }

            val currentActivity = activity
            if (currentActivity == null) {
                result.error(
                    "NO_ACTIVITY",
                    "Plugin is not attached to an Activity to request permissions",
                    null
                )
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                pendingBluetoothPermissionResult = result
                ActivityCompat.requestPermissions(
                    currentActivity,
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                    REQUEST_CODE_BLUETOOTH_CONNECT
                )
            } else {
                result.success(true)
            }
        } catch (t: Throwable) {
            Log.e(tag, "Error requesting bluetooth permission", t)
            result.success(false)
        }
    }

    private fun hasMicrophonePermission(): Boolean {
        val currentContext = context ?: return false
        return try {
            ContextCompat.checkSelfPermission(
                currentContext,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        } catch (t: Throwable) {
            Log.w(tag, "Error checking microphone permission", t)
            false
        }
    }

    private fun requestMicrophonePermission(result: Result) {
        try {
            if (hasMicrophonePermission()) {
                result.success(true)
                return
            }

            val currentActivity = activity
            if (currentActivity == null) {
                result.error(
                    "NO_ACTIVITY",
                    "Plugin is not attached to an Activity to request permissions",
                    null
                )
                return
            }

            pendingMicPermissionResult = result
            ActivityCompat.requestPermissions(
                currentActivity,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                REQUEST_CODE_RECORD_AUDIO
            )
        } catch (t: Throwable) {
            Log.e(tag, "Error requesting microphone permission", t)
            result.success(false)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        try {
            if (requestCode == REQUEST_CODE_BLUETOOTH_CONNECT) {
                val isGranted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingBluetoothPermissionResult?.success(isGranted)
                pendingBluetoothPermissionResult = null
                return true
            } else if (requestCode == REQUEST_CODE_RECORD_AUDIO) {
                val isGranted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingMicPermissionResult?.success(isGranted)
                pendingMicPermissionResult = null
                return true
            }
        } catch (t: Throwable) {
            Log.e(tag, "Error in onRequestPermissionsResult", t)
        }
        return false
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            methodChannel?.setMethodCallHandler(null)
            methodChannel = null
            eventChannel?.setStreamHandler(null)
            eventChannel = null
            unregisterNativeDeviceListeners()
            context = null
            backgroundExecutor.shutdown()
        } catch (t: Throwable) {
            Log.e(tag, "Error in onDetachedFromEngine", t)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }
}
