#include "include/audio_output_picker/audio_output_picker_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "audio_output_picker_plugin.h"

void AudioOutputPickerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  audio_output_picker::AudioOutputPickerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
