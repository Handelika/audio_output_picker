#ifndef FLUTTER_PLUGIN_AUDIO_OUTPUT_PICKER_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_OUTPUT_PICKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace audio_output_picker {

class AudioOutputPickerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AudioOutputPickerPlugin();

  virtual ~AudioOutputPickerPlugin();

  // Disallow copy and assign.
  AudioOutputPickerPlugin(const AudioOutputPickerPlugin&) = delete;
  AudioOutputPickerPlugin& operator=(const AudioOutputPickerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace audio_output_picker

#endif  // FLUTTER_PLUGIN_AUDIO_OUTPUT_PICKER_PLUGIN_H_
