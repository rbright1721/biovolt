/// What a connector can actually provide, decoupled from the
/// connector's brand or transport.
///
/// `live*` capabilities mean the connector can stream real-time samples
/// during an active session (BLE chest strap, sensor pod).
/// `summary*` capabilities mean the connector can backfill per-window
/// aggregates after the fact (Oura overnight, fitness watch daily
/// rollups).
///
/// SessionRecorder consults these to pick streaming vs. enrich-later
/// vs. manual mode.
enum DeviceCapability {
  // -- Live streaming --
  liveHeartRate,
  liveHrvRr,
  liveEcg,
  liveGsr,
  liveSpo2,
  liveTemperature,

  // -- Post-hoc summaries --
  summarySleep,
  summaryReadiness,
  summaryActivity,
  summarySpo2,
  summaryTemperature,
  summaryHeartRate,
}
