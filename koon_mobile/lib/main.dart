import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'app/theme/app_theme.dart';
import 'controllers/auth_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/compare_controller.dart';
import 'controllers/config_controller.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Register global controllers
  Get.put(AuthController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
  Get.put(CompareController(), permanent: true);
  Get.put(ConfigController(), permanent: true);
  Get.put(HomeController(), permanent: true);
  Get.put(CartController(), permanent: true);
  Get.put(OrderController(), permanent: true);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const KoonApp(),
    ),
  );
}

class KoonApp extends StatelessWidget {
  const KoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Obx(() {
      final initTheme = settingsController.isDarkMode.value ? AppTheme.darkTheme : AppTheme.lightTheme;
      return ThemeProvider(
        initTheme: initTheme,
        builder: (context, theme) {
          return GetMaterialApp(
            title: 'Koon',
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) => ThemeSwitchingArea(child: child!),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const SplashScreen(),
          );
        },
      );
    });
  }
}
