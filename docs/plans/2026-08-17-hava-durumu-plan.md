# Hava Durumu — Implementation Plan

<!-- EXECUTION CONTRACT — read before touching any task -->
> When the user asks for a specific task (e.g. "do TASK-03"):
> 1. Read **only** that task's block. Do not preview other tasks.
> 2. Stay strictly inside its **Targets** — do not edit files outside that list.
> 3. Follow the **Implementation Notes**; do not invent extra scope.
> 4. When **Done When** and **Verification** are satisfied, **stop and report**. Wait for approval before moving to the next task.
> 5. If verification fails, report the failure and stop. Do not attempt fixes outside the task's Targets.

**Goal:** Add a "Hava Durumu" tab to the app that shows the current weather (temperature + condition) for the user's GPS location.

**Architecture:** A new `WeatherService` calls the free, key-less Open-Meteo API (`https://api.open-meteo.com/v1/forecast`) with the device's lat/lon and parses the `current` block into a `WeatherInfo` model. A new `WeatherScreen` reuses the existing `LocationService` (same one `HomeScreen` already uses) to get GPS coordinates, then renders a loading/error/loaded state — mirroring the retry-with-backoff + manual "Tekrar Dene" pattern already shipped in `lib/services/overpass_service.dart` and `lib/screens/home/home_screen.dart`. The tab is wired into the existing `BottomNavigationBar` in `root_shell.dart`.

**Tech / dependencies:** No new packages. Reuses `http` (already a dependency, used by `overpass_service.dart`), `geolocator` (via existing `LocationService`), `latlong2` (`LatLng`).

**File map:**
- `lib/services/weather_service.dart` — `WeatherInfo` model, `WeatherException`, `WeatherService.fetchCurrentWeather(LatLng)` (Open-Meteo HTTP call + WMO weather-code → description/icon mapping)
- `lib/screens/weather/weather_screen.dart` — `WeatherScreen` StatefulWidget: resolves GPS location, calls `WeatherService`, renders loading / error+retry / loaded card
- `lib/screens/root_shell.dart` — add `WeatherScreen` as a third bottom-nav tab

---

### TASK-01: Weather service (Open-Meteo client + model)

**Targets:**
- `lib/services/weather_service.dart` (create)

**Model Tier:** T2

**Implementation Notes:**

Open-Meteo needs **no API key**. Request shape:

```
GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code&timezone=auto
```

Example response body:

```json
{
  "current": {
    "time": "2026-08-17T14:00",
    "temperature_2m": 27.4,
    "weather_code": 1
  },
  "current_units": {
    "temperature_2m": "°C"
  }
}
```

Follow the exact retry/timeout pattern already used in `lib/services/overpass_service.dart` (3 attempts, backoff of `attempt * 2` seconds between tries, 30s per-attempt timeout, wrap any non-domain exception into the domain exception on the final attempt). Write `lib/services/weather_service.dart` as:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WeatherInfo {
  final double temperatureCelsius;
  final String description;
  final IconData icon;
  WeatherInfo({
    required this.temperatureCelsius,
    required this.description,
    required this.icon,
  });
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
}

class WeatherService {
  static const _endpoint = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherInfo> fetchCurrentWeather(LatLng location, {int maxAttempts = 3}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,weather_code',
      'timezone': 'auto',
    });

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw WeatherException('Weather request failed: ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final current = decoded['current'] as Map<String, dynamic>;
        final code = (current['weather_code'] as num).toInt();
        final (description, icon) = _describeWeatherCode(code);

        return WeatherInfo(
          temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
          description: description,
          icon: icon,
        );
      } catch (e) {
        if (attempt == maxAttempts) {
          throw e is WeatherException ? e : WeatherException('Weather request failed: $e');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw WeatherException('Weather request failed');
  }

  (String, IconData) _describeWeatherCode(int code) {
    if (code == 0) return ('Açık', Icons.wb_sunny);
    if (code == 1) return ('Genelde açık', Icons.wb_sunny);
    if (code == 2) return ('Parçalı bulutlu', Icons.wb_cloudy);
    if (code == 3) return ('Kapalı', Icons.cloud);
    if (code == 45 || code == 48) return ('Sisli', Icons.blur_on);
    if ([51, 53, 55, 56, 57].contains(code)) return ('Çisenti', Icons.grain);
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return ('Yağmurlu', Icons.grain);
    if ([71, 73, 75, 77, 85, 86].contains(code)) return ('Kar yağışlı', Icons.ac_unit);
    if ([95, 96, 99].contains(code)) return ('Gök gürültülü fırtına', Icons.thunderstorm);
    return ('Bilinmiyor', Icons.help_outline);
  }
}
```

Note the `(String, IconData)` record return type requires Dart 3 (already satisfied — project's `environment.sdk` is `^3.9.0`, records shipped in Dart 3.0).

**Done When:**
- `WeatherService().fetchCurrentWeather(LatLng(41.0082, 28.9784))` returns a `WeatherInfo` with a populated `temperatureCelsius`, non-empty `description`, and an `icon`.
- A non-200 response or 3 consecutive failures throws `WeatherException`, not an unhandled error.

**Verification:**
- Manual: `flutter analyze` reports no issues for the new file.
- Manual: temporarily call `WeatherService().fetchCurrentWeather(...)` from a `main()` test script or a debug print in an existing screen's `initState`, run on-device, confirm a real temperature value is printed (e.g. via `flutter run` console output or `adb logcat`).

---

### TASK-02: Weather screen (GPS location + loading/error/loaded UI)

**Targets:**
- `lib/screens/weather/weather_screen.dart` (create)

**Model Tier:** T2

**Implementation Notes:**

Mirror the loading/error-with-retry structure already used in `lib/screens/home/home_screen.dart` (`_locationUnavailable`, `_nearbyPlacesFailed`, the red `Material` banner with a "Tekrar Dene" `TextButton`). `WeatherScreen` gets its own GPS fix independently (do not thread state from `HomeScreen` — each screen resolves location on its own, same as the existing codebase already does per-screen).

Reuse `LocationService` from `lib/services/location_service.dart` (`Future<LatLng?> getCurrentLocation()`) exactly as `HomeScreen._resolveLocation()` does. If location is `null`, fall back to `const LatLng(41.0082, 28.9784)` (Istanbul) — duplicate this small constant locally in this file; it's not worth extracting a shared constant for one `double` pair.

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';

const _fallbackCenter = LatLng(41.0082, 28.9784);

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _loading = true;
  bool _failed = false;
  WeatherInfo? _weather;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final location = await LocationService().getCurrentLocation() ?? _fallbackCenter;
    try {
      final weather = await WeatherService().fetchCurrentWeather(location);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
      });
    } on WeatherException {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hava Durumu')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Hava durumu yüklenemedi'),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
                    ],
                  )
                : _WeatherCard(weather: _weather!),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final WeatherInfo weather;
  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(weather.icon, size: 72),
        const SizedBox(height: 12),
        Text(
          '${weather.temperatureCelsius.round()}°C',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(weather.description, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
```

**Done When:**
- Screen shows a spinner while loading, then either the weather card (icon + rounded temperature + Turkish description) or an error state with a working "Tekrar Dene" button that re-triggers `_load()`.

**Verification:**
- Manual: `flutter analyze` reports no issues.
- Manual (on-device, after TASK-03 wires the tab in): open the tab, confirm a temperature and condition text render within a few seconds; toggle device airplane mode, reopen the tab, confirm the error state + retry button appear instead of a crash.

---

### TASK-03: Wire the tab into bottom navigation

**Targets:**
- `lib/screens/root_shell.dart` (modify)

**Model Tier:** T1

**Implementation Notes:**

Current file:

```dart
import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  static const _screens = [HomeScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Harita'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
```

Add `WeatherScreen` as the middle tab (between Harita and Profil): import `weather/weather_screen.dart`, add `WeatherScreen()` to `_screens`, add a matching `BottomNavigationBarItem(icon: Icon(Icons.wb_sunny), label: 'Hava Durumu')` in the same position. `BottomNavigationBar` needs `type: BottomNavigationBarType.fixed` once there are 3+ items, otherwise Flutter defaults to the "shifting" style meant for ≤3 items with animated backgrounds — with exactly 3 items `fixed` isn't strictly required, but set it explicitly so a later 4th tab doesn't silently change the visual style.

**Done When:**
- Bottom nav shows three tabs: Harita, Hava Durumu, Profil (in that order).
- Tapping "Hava Durumu" navigates to `WeatherScreen` without losing `HomeScreen`/`ProfileScreen` state (they stay in the `_screens` list, same as today).

**Verification:**
- Manual: `flutter analyze` reports no issues.
- Manual (real device — this project requires a separate JDK for Gradle, see below): build and install, tap through all three tabs, confirm each renders correctly and the weather tab shows live data.
  ```bash
  JAVA_HOME=~/jdk-versions/jdk-17.0.20+8 flutter build apk --debug
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  ```
  (This machine's system JDK is incompatible with this project's Gradle 8.12; the isolated JDK 17 at `~/jdk-versions/jdk-17.0.20+8` is required for `assembleDebug` to succeed — same requirement as every other build in this project.)
