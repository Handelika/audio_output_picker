#include "audio_output_picker_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <exception>

namespace audio_output_picker {

// static
void AudioOutputPickerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "audio_output_picker",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioOutputPickerPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AudioOutputPickerPlugin::AudioOutputPickerPlugin() {}

AudioOutputPickerPlugin::~AudioOutputPickerPlugin() {}

void AudioOutputPickerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    if (method_call.method_name().compare("getPlatformVersion") == 0) {
      std::ostringstream version_stream;
      version_stream << "Windows ";
      if (IsWindows10OrGreater()) {
        version_stream << "10+";
      } else if (IsWindows8OrGreater()) {
        version_stream << "8";
      } else if (IsWindows7OrGreater()) {
        version_stream << "7";
      }
      result->Success(flutter::EncodableValue(version_stream.str()));
    } else if (method_call.method_name().compare("checkBluetoothPermission") == 0 ||
               method_call.method_name().compare("checkPermission") == 0 ||
               method_call.method_name().compare("requestBluetoothPermission") == 0 ||
               method_call.method_name().compare("requestPermission") == 0 ||
               method_call.method_name().compare("checkMicrophonePermission") == 0 ||
               method_call.method_name().compare("requestMicrophonePermission") == 0) {
      result->Success(flutter::EncodableValue(true));
    } else if (method_call.method_name().compare("getAvailableAudioOutputs") == 0) {
      flutter::EncodableList list;
      flutter::EncodableMap default_device;
      default_device[flutter::EncodableValue("id")] = flutter::EncodableValue("default");
      default_device[flutter::EncodableValue("name")] = flutter::EncodableValue("Default Audio Output");
      default_device[flutter::EncodableValue("type")] = flutter::EncodableValue("speaker");
      default_device[flutter::EncodableValue("isSelected")] = flutter::EncodableValue(true);
      list.push_back(flutter::EncodableValue(default_device));
      result->Success(flutter::EncodableValue(list));
    } else if (method_call.method_name().compare("selectAudioOutput") == 0) {
      result->Success(flutter::EncodableValue(true));
    } else if (method_call.method_name().compare("getCurrentAudioOutput") == 0) {
      flutter::EncodableMap default_device;
      default_device[flutter::EncodableValue("id")] = flutter::EncodableValue("default");
      default_device[flutter::EncodableValue("name")] = flutter::EncodableValue("Default Audio Output");
      default_device[flutter::EncodableValue("type")] = flutter::EncodableValue("speaker");
      default_device[flutter::EncodableValue("isSelected")] = flutter::EncodableValue(true);
      result->Success(flutter::EncodableValue(default_device));
    } else if (method_call.method_name().compare("getAvailableMicrophones") == 0) {
      flutter::EncodableList list;
      flutter::EncodableMap default_device;
      default_device[flutter::EncodableValue("id")] = flutter::EncodableValue("default_mic");
      default_device[flutter::EncodableValue("name")] = flutter::EncodableValue("Default Microphone");
      default_device[flutter::EncodableValue("type")] = flutter::EncodableValue("builtInMic");
      default_device[flutter::EncodableValue("isSelected")] = flutter::EncodableValue(true);
      list.push_back(flutter::EncodableValue(default_device));
      result->Success(flutter::EncodableValue(list));
    } else if (method_call.method_name().compare("selectMicrophone") == 0) {
      result->Success(flutter::EncodableValue(true));
    } else if (method_call.method_name().compare("getCurrentMicrophone") == 0) {
      flutter::EncodableMap default_device;
      default_device[flutter::EncodableValue("id")] = flutter::EncodableValue("default_mic");
      default_device[flutter::EncodableValue("name")] = flutter::EncodableValue("Default Microphone");
      default_device[flutter::EncodableValue("type")] = flutter::EncodableValue("builtInMic");
      default_device[flutter::EncodableValue("isSelected")] = flutter::EncodableValue(true);
      result->Success(flutter::EncodableValue(default_device));
    } else {
      result->NotImplemented();
    }
  } catch (const std::exception& e) {
    result->Error("CPP_EXCEPTION", e.what());
  } catch (...) {
    result->Error("CPP_UNKNOWN_EXCEPTION", "An unknown C++ exception occurred.");
  }
}

}  // namespace audio_output_picker
