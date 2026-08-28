#include "include/audio_output_picker/audio_output_picker_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "audio_output_picker_plugin_private.h"

#define AUDIO_OUTPUT_PICKER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), audio_output_picker_plugin_get_type(), \
                              AudioOutputPickerPlugin))

struct _AudioOutputPickerPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(AudioOutputPickerPlugin, audio_output_picker_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void audio_output_picker_plugin_handle_method_call(
    AudioOutputPickerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  if (method_call == nullptr) {
    return;
  }

  const gchar* method = fl_method_call_get_name(method_call);
  if (method == nullptr) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "checkBluetoothPermission") == 0 ||
             strcmp(method, "checkPermission") == 0 ||
             strcmp(method, "requestBluetoothPermission") == 0 ||
             strcmp(method, "requestPermission") == 0 ||
             strcmp(method, "checkMicrophonePermission") == 0 ||
             strcmp(method, "requestMicrophonePermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getAvailableAudioOutputs") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    g_autoptr(FlValue) device = fl_value_new_map();
    fl_value_set_string_take(device, "id", fl_value_new_string("default"));
    fl_value_set_string_take(device, "name", fl_value_new_string("Default Audio Output"));
    fl_value_set_string_take(device, "type", fl_value_new_string("speaker"));
    fl_value_set_string_take(device, "isSelected", fl_value_new_bool(TRUE));
    fl_value_append(list, device);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (strcmp(method, "selectAudioOutput") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getCurrentAudioOutput") == 0) {
    g_autoptr(FlValue) device = fl_value_new_map();
    fl_value_set_string_take(device, "id", fl_value_new_string("default"));
    fl_value_set_string_take(device, "name", fl_value_new_string("Default Audio Output"));
    fl_value_set_string_take(device, "type", fl_value_new_string("speaker"));
    fl_value_set_string_take(device, "isSelected", fl_value_new_bool(TRUE));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(device));
  } else if (strcmp(method, "getAvailableMicrophones") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    g_autoptr(FlValue) device = fl_value_new_map();
    fl_value_set_string_take(device, "id", fl_value_new_string("default_mic"));
    fl_value_set_string_take(device, "name", fl_value_new_string("Default Microphone"));
    fl_value_set_string_take(device, "type", fl_value_new_string("builtInMic"));
    fl_value_set_string_take(device, "isSelected", fl_value_new_bool(TRUE));
    fl_value_append(list, device);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (strcmp(method, "selectMicrophone") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getCurrentMicrophone") == 0) {
    g_autoptr(FlValue) device = fl_value_new_map();
    fl_value_set_string_take(device, "id", fl_value_new_string("default_mic"));
    fl_value_set_string_take(device, "name", fl_value_new_string("Default Microphone"));
    fl_value_set_string_take(device, "type", fl_value_new_string("builtInMic"));
    fl_value_set_string_take(device, "isSelected", fl_value_new_bool(TRUE));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(device));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void audio_output_picker_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(audio_output_picker_plugin_parent_class)->dispose(object);
}

static void audio_output_picker_plugin_class_init(AudioOutputPickerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = audio_output_picker_plugin_dispose;
}

static void audio_output_picker_plugin_init(AudioOutputPickerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  AudioOutputPickerPlugin* plugin = AUDIO_OUTPUT_PICKER_PLUGIN(user_data);
  audio_output_picker_plugin_handle_method_call(plugin, method_call);
}

void audio_output_picker_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  AudioOutputPickerPlugin* plugin = AUDIO_OUTPUT_PICKER_PLUGIN(
      g_object_new(audio_output_picker_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "audio_output_picker",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
