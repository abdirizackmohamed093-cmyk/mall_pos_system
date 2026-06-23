//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <print_bluetooth_thermal/print_bluetooth_thermal_plugin_c_api.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  PrintBluetoothThermalPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PrintBluetoothThermalPluginCApi"));
  Sqlite3FlutterLibsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("Sqlite3FlutterLibsPlugin"));
}
