import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/accessibility_tokens.dart';
import 'theme/app_theme.dart';

class VisionMateApp extends ConsumerWidget {
  const VisionMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    ThemeData selectedTheme;
    switch (themeMode) {
      case AppThemeMode.highContrast:
        selectedTheme = AppTheme.highContrastTheme;
        break;
      case AppThemeMode.light:
        selectedTheme = AppTheme.lightTheme;
        break;
      case AppThemeMode.dark:
        selectedTheme = AppTheme.darkTheme;
        break;
    }

    return MaterialApp.router(
      title: 'VisionMate 2.0',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme,
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('mr', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (context, child) {
        // Enforce accessible font scaling constraints to prevent clip/overflow
        final mediaQueryData = MediaQuery.of(context);
        final constrainedTextScale = mediaQueryData.textScaler.clamp(
          minScaleFactor: AccessibilityTokens.minFontScaleFactor,
          maxScaleFactor: AccessibilityTokens.maxFontScaleFactor,
        );

        return MediaQuery(
          data: mediaQueryData.copyWith(textScaler: constrainedTextScale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
