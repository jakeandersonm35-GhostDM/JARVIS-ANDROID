import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'app.dart';
import 'overlay/overlay_app.dart';
import 'services/calendar_reminder_service.dart';
import 'services/hermes_evolution_service.dart';
import 'services/jarvis_service.dart';
import 'services/native_bridge_service.dart';
import 'services/screen_automation_service.dart';
import 'services/sentry_service.dart';
import 'services/settings_service.dart';
import 'services/task_executor.dart';
import 'services/telegram_service.dart';
import 'services/todo_service.dart';

Future<void> main() async {
  // Log framework errors instead of letting one bad widget/service take the app down.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[JARVIS] Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[JARVIS] Uncaught async error: $error\n$stack');
    return true; // handled
  };

  await runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('[JARVIS] Uncaught zone error: $error\n$stack');
  });
}

/// Runs one startup step; a failure is logged and the app still launches.
Future<void> _safeInit(String name, FutureOr<void> Function() step) async {
  try {
    await step();
  } catch (error, stack) {
    debugPrint('[JARVIS] Startup step "$name" failed: $error\n$stack');
  }
}

Future<void> _bootstrap() async {
  // Binding and runApp must share one zone, so initialise inside the guarded zone.
  WidgetsFlutterBinding.ensureInitialized();
  NativeBridgeService.instance.init();

  final settings = SettingsService.instance;
  // Settings are required for the UI (onboarding flag, theme): retry once.
  try {
    await settings.init();
  } catch (_) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _safeInit('settings', settings.init);
  }

  final executor = TaskExecutor.instance;
  await _safeInit('task executor', executor.init);
  await _safeInit('hermes evolution', HermesEvolutionService.instance.init);
  await _safeInit('calendar reminders', CalendarReminderService.instance.init);
  await _safeInit('todo', TodoService.instance.init);

  await _safeInit('jarvis always-on', () {
    if (settings.jarvisAlwaysOn) {
      JarvisService.instance.ensureAlwaysOnRunning();
    }
  });

  await _safeInit('telegram wiring', () => _wireTelegram(executor, settings));
  await _safeInit('overlay wiring', () => _wireOverlayCommands(executor));

  runApp(const PrivateAgentApp());
}

/// Telegram bot -> task executor wiring.
void _wireTelegram(TaskExecutor executor, SettingsService settings) {
  final telegram = TelegramService.instance;

  telegram.onCommand = (chatId, text) async {
    final lower = text.toLowerCase();
    if (lower == '/status') {
      final running = executor.isBusy
          ? 'Running "${executor.currentGoal}" (step ${executor.step})'
          : 'Idle';
      final serviceOn =
          await ScreenAutomationService.instance.isServiceEnabled();
      await telegram.sendMessage(chatId,
          '📱 $running\nAccessibility service: ${serviceOn ? 'ON ✅' : 'OFF ❌'}');
      return;
    }
    if (lower == '/screenshot') {
      final shot =
          await ScreenAutomationService.instance.takeScreenshotBase64();
      if (shot == null) {
        await telegram.sendMessage(chatId, '⚠️ Screenshot failed.');
      } else {
        await telegram.sendScreenshot(chatId, shot);
      }
      return;
    }
    if (lower == '/cancel' || lower == '/stop') {
      if (executor.isBusy) {
        executor.cancel();
        await telegram.sendMessage(chatId, '⏹️ Cancelling current task…');
      } else {
        await telegram.sendMessage(chatId, 'Nothing is running.');
      }
      return;
    }
    if (executor.isBusy) {
      await telegram.sendMessage(
          chatId, '⏳ Busy with another task. Send /cancel to stop it.');
      return;
    }
    await telegram.sendMessage(chatId, '🚀 Starting task: $text');
    unawaited(executor.executeTask(text, telegramChatId: chatId));
  };

  // Push the final result (plus screenshot) back to the originating chat.
  executor.onTaskFinished = (chatId, entry) async {
    await telegram.sendMessage(chatId, telegram.formatTaskResult(entry));
    final shot = await ScreenAutomationService.instance.takeScreenshotBase64();
    if (shot != null) {
      await telegram.sendScreenshot(chatId, shot,
          caption: 'Final screen state');
    }
  };

  if (settings.telegramEnabled) {
    unawaited(telegram.start());
  }
}

/// Commands coming from the floating overlay bubble/panel.
void _wireOverlayCommands(TaskExecutor executor) {
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event is! String) return;
    Map<String, dynamic> decoded;
    try {
      final d = jsonDecode(event);
      if (d is! Map) return;
      decoded = d.map((k, v) => MapEntry('$k', v));
    } catch (_) {
      return;
    }
    if (decoded['type'] != 'command') return;
    switch (decoded['command']) {
      case 'start':
        final goal = decoded['goal']?.toString().trim() ?? '';
        if (goal.isNotEmpty && !executor.isBusy) {
          unawaited(executor.executeTask(goal));
        }
        break;
      case 'pause':
        executor.pause();
        break;
      case 'resume':
        executor.resume();
        break;
      case 'cancel':
        executor.cancel();
        break;
      case 'summarize_screen':
        unawaited(JarvisService.instance.processCommand('summarize this screen article'));
        break;
      case 'jarvis_command':
        final goal = decoded['goal']?.toString().trim() ?? '';
        if (goal.isNotEmpty) {
          unawaited(JarvisService.instance.processCommand(goal));
        }
        break;
      case 'toggle_sentry':
        unawaited(SentryService.instance.toggleSentry());
        break;
    }
  });
}

/// Entry point for the floating overlay window (separate Flutter engine
/// running in its own isolate). Must stay a top-level function annotated
/// with vm:entry-point.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
