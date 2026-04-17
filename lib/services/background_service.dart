import 'package:workmanager/workmanager.dart';
import 'widget_service.dart';

const _widgetRefreshTask = 'biovolt.widget.refresh';

/// Top-level callback — required by workmanager. Must be a top-level
/// function (not a method) because the plugin spawns it on a separate
/// Dart isolate that has no access to class instances.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _widgetRefreshTask) {
      try {
        await WidgetService.updateWidget();
      } catch (_) {
        // Never throw from a background task — that just pings the
        // backoff retry loop and burns battery.
      }
    }
    return true;
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> scheduleWidgetRefresh() async {
    // Cancel any existing task first to avoid duplicates across restarts.
    await Workmanager().cancelByUniqueName(_widgetRefreshTask);

    await Workmanager().registerPeriodicTask(
      _widgetRefreshTask,
      _widgetRefreshTask,
      // Android's hard minimum is 15 minutes — the system may batch
      // longer under Doze or aggressive battery saver.
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  static Future<void> cancelWidgetRefresh() async {
    await Workmanager().cancelByUniqueName(_widgetRefreshTask);
  }
}
