/// Single source of truth for BiovoltEvent type strings.
///
/// All events emitted through [EventLog.append] should pull their `type`
/// from this file. Adding a new event means adding a constant here —
/// downstream code (timeline screen, sync, analytics) will enumerate
/// these to know what's possible.
///
/// Naming convention: `domain.action` in lower snake_case after the dot.
/// Past-tense for things that already happened (`session.started`),
/// imperative only for commands / requests (`analysis.requested`).
class EventTypes {
  EventTypes._();

  // -- Profile ----------------------------------------------------------
  static const profileFieldChanged = 'profile.field_changed';
  static const profileGeneticMarkerAdded = 'profile.genetic_marker_added';
  static const profileBloodworkAdded = 'profile.bloodwork_added';

  // -- Protocol ---------------------------------------------------------
  static const protocolItemAdded = 'protocol.item_added';
  static const protocolItemRemoved = 'protocol.item_removed';
  static const protocolItemModified = 'protocol.item_modified';
  static const protocolVersionCommitted = 'protocol.version_committed';

  // -- Interventions / supplements --------------------------------------
  static const supplementAdded = 'supplement.added';
  static const supplementRemoved = 'supplement.removed';
  static const supplementLogged = 'supplement.logged';

  // -- Sessions ---------------------------------------------------------
  static const sessionStarted = 'session.started';
  static const sessionEnded = 'session.ended';
  static const sessionAnnotationAdded = 'session.annotation_added';

  // -- Sensor samples ---------------------------------------------------
  static const hrSample = 'hr.sample';
  static const hrvSample = 'hrv.sample';
  static const gsrSample = 'gsr.sample';
  static const ecgSample = 'ecg.sample';
  static const spo2Sample = 'spo2.sample';
  static const temperatureSample = 'temperature.sample';

  // -- Devices ----------------------------------------------------------
  static const deviceConnected = 'device.connected';
  static const deviceDisconnected = 'device.disconnected';
  static const devicePaired = 'device.paired';

  // -- Oura imports -----------------------------------------------------
  static const ouraSleepImported = 'oura.sleep_imported';
  static const ouraReadinessImported = 'oura.readiness_imported';
  static const ouraActivityImported = 'oura.activity_imported';

  // -- Journal ----------------------------------------------------------
  static const journalEntryAdded = 'journal.entry_added';
  static const journalEntryEdited = 'journal.entry_edited';

  // -- AI ---------------------------------------------------------------
  static const analysisRequested = 'analysis.requested';
  static const analysisCompleted = 'analysis.completed';
  static const coachingMessageDelivered = 'coaching.message_delivered';

  // -- Lifecycle --------------------------------------------------------
  static const fastingStarted = 'fasting.started';
  static const fastingEnded = 'fasting.ended';
  static const mealLogged = 'meal.logged';
}
