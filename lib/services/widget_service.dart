import 'package:home_widget/home_widget.dart';
import 'storage_service.dart';

class WidgetService {
  static const _appGroupId = 'com.biovolt.app';

  static Future<void> updateWidget() async {
    await HomeWidget.setAppGroupId(_appGroupId);

    final storage = StorageService();
    final profile = storage.getUserProfile();

    // ── Sync "I ate" from widget back to Hive ─────────────────────
    // If the widget button was pressed while the app was closed,
    // last_meal_epoch_ms in SharedPreferences will be newer than
    // lastMealTime in Hive. Mirror it back into the profile so the
    // rest of the app stays consistent.
    final widgetMealEpoch = await HomeWidget
            .getWidgetData<int>('last_meal_epoch_ms', defaultValue: 0) ??
        0;
    if (widgetMealEpoch > 0 && profile != null) {
      final widgetMealTime =
          DateTime.fromMillisecondsSinceEpoch(widgetMealEpoch);
      if (profile.lastMealTime == null ||
          widgetMealTime.isAfter(profile.lastMealTime!)) {
        await storage.updateLastMealTimeExplicit(widgetMealTime);
      }
    }

    // Re-read after possible sync.
    final updatedProfile = storage.getUserProfile();

    // ── Fasting time string (fallback if Kotlin can't compute) ────
    String fastingText = '--h --m';
    if (updatedProfile?.lastMealTime != null) {
      final elapsed =
          DateTime.now().difference(updatedProfile!.lastMealTime!);
      fastingText = '${elapsed.inHours}h '
          '${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}m';
    }

    // ── Eating window integers for Kotlin ──────────────────────────
    final eatStart = updatedProfile?.eatWindowStartHour ?? -1;
    final eatEnd = updatedProfile?.eatWindowEndHour ?? -1;
    final fastingType = updatedProfile?.fastingType ?? 'none';

    // ── Active protocols ───────────────────────────────────────────
    final protocols = storage.getAllActiveProtocols();
    String protocolText = 'No active protocols';
    if (protocols.isNotEmpty) {
      final p = protocols.first;
      final ongoing = p.cycleLengthDays == 0 || p.cycleLengthDays == 365;
      final dayStr = ongoing
          ? 'Day ${p.currentCycleDay}'
          : 'Day ${p.currentCycleDay}/${p.cycleLengthDays}';
      protocolText = '${p.name} \u00B7 $dayStr';
      if (protocols.length > 1) {
        protocolText += ' +${protocols.length - 1}';
      }
    }

    // ── Data slot: last session HRV (+ HR if available) ────────────
    String dataSlot = '';
    final sessions = storage.getAllSessions();
    if (sessions.isNotEmpty) {
      final last = sessions.first;
      final hrv = last.biometrics?.computed?.hrvRmssdMs;
      final hr = last.biometrics?.computed?.heartRateMeanBpm;
      if (hrv != null && hrv > 0) {
        dataSlot = 'Last HRV ${hrv.toStringAsFixed(0)}ms';
        if (hr != null && hr > 0) {
          dataSlot += ' \u00B7 HR ${hr.toStringAsFixed(0)}';
        }
      }
    }

    // ── Save to widget ─────────────────────────────────────────────
    await HomeWidget.saveWidgetData<String>('fasting_time', fastingText);
    await HomeWidget.saveWidgetData<String>('protocol_text', protocolText);
    await HomeWidget.saveWidgetData<String>('data_slot', dataSlot);
    await HomeWidget.saveWidgetData<int>('eat_window_start', eatStart);
    await HomeWidget.saveWidgetData<int>('eat_window_end', eatEnd);
    await HomeWidget.saveWidgetData<String>('fasting_type', fastingType);

    await HomeWidget.updateWidget(androidName: 'BioVoltWidget');
  }
}
