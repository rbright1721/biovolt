import 'package:home_widget/home_widget.dart';
import 'storage_service.dart';

class WidgetService {
  static const _appGroupId = 'com.biovolt.app';

  static Future<void> updateWidget() async {
    await HomeWidget.setAppGroupId(_appGroupId);

    final storage = StorageService();

    // ── Fasting time ──────────────────────────────────────────────────
    final profile = storage.getUserProfile();
    String fastingText = '--:--';
    if (profile?.lastMealTime != null) {
      final elapsed = DateTime.now().difference(profile!.lastMealTime!);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes % 60;
      fastingText = '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}';
    }

    // ── Active protocols ──────────────────────────────────────────────
    final protocols = storage.getAllActiveProtocols();
    String protocolText = 'No active protocols';
    if (protocols.isNotEmpty) {
      final first = protocols.first;
      final ongoing =
          first.cycleLengthDays == 0 || first.cycleLengthDays == 365;
      final dayStr = ongoing
          ? 'Day ${first.currentCycleDay} \u2014 ongoing'
          : 'Day ${first.currentCycleDay}/${first.cycleLengthDays}';
      protocolText = '${first.name} \u00B7 $dayStr';
      if (protocols.length > 1) {
        protocolText += ' +${protocols.length - 1} more';
      }
    }

    // ── Last session HRV ──────────────────────────────────────────────
    String hrvText = '';
    final sessions = storage.getAllSessions();
    if (sessions.isNotEmpty) {
      final last = sessions.first;
      final hrv = last.biometrics?.computed?.hrvRmssdMs;
      if (hrv != null && hrv > 0) {
        hrvText = 'Last HRV: ${hrv.toStringAsFixed(0)}ms';
      }
    }

    // ── Save to widget storage ────────────────────────────────────────
    await HomeWidget.saveWidgetData<String>('fasting_time', fastingText);
    await HomeWidget.saveWidgetData<String>('protocol_text', protocolText);
    await HomeWidget.saveWidgetData<String>('hrv_text', hrvText);

    // ── Trigger widget refresh ────────────────────────────────────────
    await HomeWidget.updateWidget(androidName: 'BioVoltWidget');
  }
}
