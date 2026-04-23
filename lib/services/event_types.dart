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
  // Added so trend analysis can tell "new lab drawn" from "typo fix on
  // existing lab" — both flow through saveBloodwork but have very
  // different analytical meaning.
  static const profileBloodworkEdited = 'profile.bloodwork_edited';
  // Added for deleteBloodwork — deletions need their own type so the log
  // doesn't conflate creations and removals.
  static const profileBloodworkRemoved = 'profile.bloodwork_removed';

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
  // Added for deleteSession — a deleted session is a distinct signal
  // from an ended one (ended = completed, discarded = removed).
  static const sessionDiscarded = 'session.discarded';

  // -- Session templates ------------------------------------------------
  // Templates are reusable session recipes, not sessions themselves.
  // Added as a sub-domain so timeline consumers can filter them out.
  static const sessionTemplateSaved = 'session.template_saved';
  static const sessionTemplateDeleted = 'session.template_deleted';
  static const sessionTemplateUsed = 'session.template_used';

  // -- Sensor samples ---------------------------------------------------
  static const hrSample = 'hr.sample';
  static const hrvSample = 'hrv.sample';
  static const gsrSample = 'gsr.sample';
  static const ecgSample = 'ecg.sample';
  static const spo2Sample = 'spo2.sample';
  static const temperatureSample = 'temperature.sample';

  // -- Devices ----------------------------------------------------------
  // The specific types below are reserved for user-initiated actions.
  // Automatic BLE reconnects and connector-registry bookkeeping emit
  // [deviceStateChanged] instead, so the log captures every persisted
  // state write without burying genuine user actions in noise.
  static const deviceConnected = 'device.connected';
  static const deviceDisconnected = 'device.disconnected';
  static const devicePaired = 'device.paired';
  static const deviceStateChanged = 'device.state_changed';

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
  // Added for deleteAiAnalysis — typically used before regenerating an
  // analysis; worth recording since reanalysis history is interesting.
  static const analysisDiscarded = 'analysis.discarded';
  static const coachingMessageDelivered = 'coaching.message_delivered';

  // -- Lifecycle --------------------------------------------------------
  static const fastingStarted = 'fasting.started';
  static const fastingEnded = 'fasting.ended';
  static const mealLogged = 'meal.logged';

  // -- Bookmarks --------------------------------------------------------
  // Added as a new sub-domain — a vitals bookmark is a user-initiated
  // snapshot of live sensor values, distinct from session data and
  // journal entries.
  static const bookmarkAdded = 'bookmark.added';

  // -- App-level --------------------------------------------------------
  // Added for clearAll — a full wipe of state boxes is a meaningful
  // lifecycle event that the event log (which survives the wipe) should
  // record for audit purposes.
  static const appDataCleared = 'app.data_cleared';

  // -- Timeline / LogEntry ----------------------------------------------
  // User observations captured as free-text or voice notes, then
  // upgraded by the classifier worker into typed entries. See [LogEntry].
  // Storage-layer emit sites: saveLogEntry → entryCreated,
  // updateLogEntryClassification → entryClassified or entryReclassified.
  // [entryDeleted] is kept for the upcoming delete-entry UI flow;
  // [entryEdited] was removed in the 2026-04-22 cleanup — re-add it
  // when an edit flow lands.
  static const entryCreated = 'timeline.entry_created';
  static const entryClassified = 'timeline.entry_classified';
  static const entryReclassified = 'timeline.entry_reclassified';
  static const entryDeleted = 'timeline.entry_deleted';
}
