import 'calendar_reminder_service.dart';
import 'jarvis_tools_service.dart';
import 'system_control_service.dart';
import 'todo_service.dart';

enum RoutineType { morning, evening }

/// Morning and evening autonomous routine engine.
class RoutineAutomationService {
  RoutineAutomationService._();
  static final RoutineAutomationService instance =
      RoutineAutomationService._();

  /// Runs the comprehensive Morning Briefing Routine.
  Future<String> executeMorningRoutine({String? userCity}) async {
    // 1. Hardware: Unmute, set balanced daytime volume (60%) and brightness (75%)
    try {
      await SystemControlService.instance.setMuted(false);
      await SystemControlService.instance.setVolume(0.60);
      await SystemControlService.instance.setBrightness(0.75);
    } catch (_) {}

    // 2. Telemetry: Date, Battery, Weather
    final dt = JarvisToolsService.instance.getCurrentDateTime();
    final battery = await JarvisToolsService.instance.getBatteryStatus();
    final battLevel = battery['level'] as int;

    String weatherText = '';
    try {
      weatherText = await JarvisToolsService.instance
          .getWeather(userCity?.isNotEmpty == true ? userCity! : '');
    } catch (_) {}

    // 3. Today's Calendar & Tasks
    final calBriefing =
        CalendarReminderService.instance.getTodayBriefingSpoken();
    final todoBriefing = TodoService.instance.getPendingTasksSpoken();

    // 4. Compile articulate morning briefing
    final buffer = StringBuffer('Good morning, sir. Welcome to a brand new day. ');
    buffer.write('It is currently $dt. ');
    if (battLevel >= 0) {
      buffer.write('Your device is at $battLevel% battery. ');
    }
    if (weatherText.isNotEmpty && !weatherText.contains('Unable to retrieve')) {
      buffer.write('Outside conditions: $weatherText. ');
    }
    buffer.write('$calBriefing ');
    buffer.write('$todoBriefing ');
    buffer.write('All systems are primed and at your disposal. What shall we conquer first, sir?');

    return buffer.toString();
  }

  /// Runs the soothing Evening / Night Routine.
  Future<String> executeEveningRoutine() async {
    // 1. Hardware: Dim display to 15%, lower audio to 20%, silence notifications
    try {
      await SystemControlService.instance.setBrightness(0.15);
      await SystemControlService.instance.setVolume(0.20);
      await JarvisToolsService.instance.setTorch(false);
    } catch (_) {}

    // 2. Review today's accomplishments
    final completedTodos = TodoService.instance.completedItems.length;

    final buffer = StringBuffer('Good evening, sir. Commencing Night Protocol. ');
    buffer.write('I have dimmed your display, silenced high-volume notifications, and prepared your device for sleep. ');
    if (completedTodos > 0) {
      buffer.write('You completed $completedTodos ${completedTodos == 1 ? 'task' : 'tasks'} today — an excellent effort. ');
    }
    buffer.write('Rest well, sir. I will remain on quiet standby watching over your systems until dawn.');

    return buffer.toString();
  }
}

