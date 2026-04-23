/// Known chest-strap device identities.
///
/// Maps an advertised BLE name pattern to a display label and a
/// `supportsEcg` flag. Pairing does NOT consult this list — any device
/// advertising the standard BLE Heart Rate Service (0x180D) is eligible.
/// This registry only feeds (a) the UI label and (b) whether to try
/// streaming proprietary ECG from the device.
///
/// The `supportsEcg` field is retained for forward compatibility with a
/// future Polar PMD-over-flutter_blue_plus reimplementation. For now
/// every entry is `false` — the current connector talks only to the
/// standard HR Service (0x2A37) for heart rate + R-R intervals.
library;

class ChestStrapDeviceProfile {
  /// Case-insensitive substring matched against the advertised BLE name.
  final String namePattern;

  /// Human-readable label shown in the UI.
  final String label;

  /// Whether the device exposes a proprietary ECG characteristic the
  /// connector can subscribe to. Unused until a PMD reimplementation
  /// lands; kept on the profile to make the intent explicit.
  final bool supportsEcg;

  const ChestStrapDeviceProfile({
    required this.namePattern,
    required this.label,
    required this.supportsEcg,
  });
}

/// Ordered list — first match wins.
const List<ChestStrapDeviceProfile> kChestStrapKnownDevices = [
  ChestStrapDeviceProfile(
    namePattern: 'Polar H10',
    label: 'Polar H10',
    supportsEcg: false,
  ),
  ChestStrapDeviceProfile(
    namePattern: 'H9Z',
    label: 'Coospo H9Z',
    supportsEcg: false,
  ),
];

/// Resolve a BLE-advertised name to a profile. Returns an unknown-device
/// profile that echoes [advertisedName] as its label and has
/// `supportsEcg: false` when nothing matches.
ChestStrapDeviceProfile resolveChestStrapProfile(String advertisedName) {
  final needle = advertisedName.toLowerCase();
  for (final entry in kChestStrapKnownDevices) {
    if (needle.contains(entry.namePattern.toLowerCase())) return entry;
  }
  return ChestStrapDeviceProfile(
    namePattern: advertisedName,
    label: advertisedName.isEmpty ? 'Chest Strap' : advertisedName,
    supportsEcg: false,
  );
}
