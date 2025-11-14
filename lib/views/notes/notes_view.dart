// lib/views/notes/notes_view.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynotesapp/constants/routes.dart';
import 'package:mynotesapp/enums/menu_action.dart';
import 'package:mynotesapp/extensions/buildcontext/loc.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';
import 'package:mynotesapp/services/auth/bloc/auth_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_event.dart';
import 'package:mynotesapp/services/cloud/cloud_note.dart';
import 'package:mynotesapp/services/cloud/firebase_cloud_storage.dart';
import 'package:mynotesapp/services/weather_service.dart';
import 'package:mynotesapp/utilities/dialogs/logout_dialog.dart';
import 'package:mynotesapp/views/login_view.dart';
import 'package:mynotesapp/views/notes/notes_list_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geolocator/geolocator.dart';

extension Count<T extends Iterable> on Stream<T> {
  Stream<int> get getLength => map((event) => event.length);
}

class NotesView extends StatefulWidget {
  final WeatherData? weatherData;
  const NotesView({super.key, this.weatherData});

  @override
  NotesViewState createState() => NotesViewState();
}

class NotesViewState extends State<NotesView> {
  late final FirebaseCloudStorage _notesService;
  final WeatherService _weatherService = WeatherService();

  WeatherData? _weatherData;
  String? _weatherError;
  Timer? _refreshTimer;
  bool _isLoadingWeather = false;

  String get userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _notesService = FirebaseCloudStorage();

    _weatherData = widget.weatherData;
    if (_weatherData == null) {
      _fetchAndSetWeather();
    }

    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _fetchAndSetWeather();
    });
  }

  Future<void> _fetchAndSetWeather() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoadingWeather = true;
        _weatherError = null;
      });

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _weatherError = 'Location permission denied.';
          _isLoadingWeather = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final weather =
          await _weatherService.fetchWeather(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _weatherData = weather;
        _weatherError = weather == null ? 'Failed to fetch weather.' : null;
        _isLoadingWeather = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = 'Error fetching weather: $e';
        _isLoadingWeather = false;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showLogOutDialog(context);
    if (!shouldLogout || !mounted) return;

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    context.read<AuthBloc>().add(const AuthEventLogOut());
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weatherData ?? widget.weatherData;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder(
          stream: _notesService.allNotes(ownerUserId: userId).getLength,
          builder: (context, AsyncSnapshot<int> snapshot) {
            if (snapshot.hasData) {
              final count = snapshot.data ?? 0;
              return Text(context.loc.notes_title(count));
            }
            return const Text('');
          },
        ),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(createOrUpdateNoteRoute),
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton<MenuAction>(
            onSelected: (value) async {
              if (value == MenuAction.logout) await _handleLogout(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: MenuAction.logout,
                child: Text(context.loc.logout_button),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _buildWeatherTile(weather),
          ),

          Expanded(
            child: StreamBuilder(
              stream: _notesService.allNotes(ownerUserId: userId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final notes = snapshot.data as Iterable<CloudNote>;
                  return NotesListView(
                    notes: notes,
                    onDeleteNote: (note) async {
                      await _notesService.deleteNote(
                        documentId: note.documentId,
                      );
                    },
                    onTap: (note) {
                      Navigator.of(context).pushNamed(
                        createOrUpdateNoteRoute,
                        arguments: note,
                      );
                    },
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // WEATHER TILE
  // ==========================================================
  Widget _buildWeatherTile(WeatherData? weather) {
    if (_isLoadingWeather && weather == null) {
      return _infoCard(
        child: Row(
          children: const [
            Expanded(child: Text('Fetching weather...')),
            SizedBox(width: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    if (_weatherError != null && weather == null) {
      return GestureDetector(
        onTap: _fetchAndSetWeather,
        child: _infoCard(
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weather unavailable — tap to retry.\n$_weatherError',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (weather != null) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeatherDetailView(weather: weather),
          ),
        ),
        child: _infoCard(
          child: Row(
            children: [
              Image.network(
                'https://openweathermap.org/img/wn/${weather.icon}@2x.png',
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const Icon(Icons.cloud, size: 42),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.city,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${weather.temperature.toStringAsFixed(1)}°C • ${toBeginningOfSentenceCase(weather.description) ?? weather.description}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pillStat(Icons.thermostat_outlined, 'Feels',
                            '${weather.feelsLike.toStringAsFixed(1)}°C'),
                        _pillStat(Icons.water_drop, 'Humidity',
                            '${weather.humidity}%'),
                        _pillStat(Icons.air, 'Wind',
                            '${weather.windSpeed.toStringAsFixed(1)} m/s'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _fetchAndSetWeather,
                icon: const Icon(Icons.refresh),
              )
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _pillStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4178C0).withAlpha(40), // darker blue
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ==========================================================
// FULL WEATHER DETAIL SCREEN
// ==========================================================
class WeatherDetailView extends StatelessWidget {
  final WeatherData weather;
  const WeatherDetailView({super.key, required this.weather});

  String _formatTime(DateTime time) =>
      DateFormat.jm().format(time.toLocal());

  List<Color> _gradientFor(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('rain')) {
      return [Colors.blueGrey.shade700, Colors.blue.shade400];
    } else if (d.contains('cloud')) {
      return [Colors.blue.shade600, Colors.grey.shade400];
    } else if (d.contains('clear')) {
      return [Colors.orangeAccent, Colors.yellow.shade200];
    } else if (d.contains('snow')) {
      return [Colors.lightBlue.shade200, Colors.white];
    }
    return [Colors.teal.shade400, Colors.cyan.shade200];
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(weather.description);

    return Scaffold(
      appBar: AppBar(
        title: Text(weather.city),
        backgroundColor: gradient.first,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================================
                // CURRENT WEATHER CARD
                // ==========================================================
                _card(
                  child: Row(
                    children: [
                      Image.network(
                        'https://openweathermap.org/img/wn/${weather.icon}@4x.png',
                        width: 110,
                        height: 110,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.wb_sunny,
                                size: 96, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperature.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              toBeginningOfSentenceCase(
                                      weather.description) ??
                                  weather.description,
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _detailChip(Icons.thermostat,
                                    'Feels: ${weather.feelsLike.toStringAsFixed(1)}°C'),
                                _detailChip(Icons.water_drop,
                                    'Humidity: ${weather.humidity}%'),
                                _detailChip(Icons.air,
                                    'Wind: ${weather.windSpeed.toStringAsFixed(1)} m/s'),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ==========================================================
                // SUNRISE / SUNSET
                // ==========================================================
                _card(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.wb_sunny_outlined,
                              color: Colors.yellowAccent, size: 28),
                          const SizedBox(height: 6),
                          const Text('Sunrise',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(weather.daily.first.sunrise),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.nightlight_round,
                              color: Colors.orangeAccent, size: 28),
                          const SizedBox(height: 6),
                          const Text('Sunset',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(weather.daily.first.sunset),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ==========================================================
                // HOURLY FORECAST (every hour now!)
                // ==========================================================
                _sectionTitle('Hourly (next 24h)'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: weather.hourly.length,
                    itemBuilder: (_, idx) {
                      final h = weather.hourly[idx];
                      return Container(
                        width: 86,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            Text(
                              h.hourLabel,
                              style:
                                  const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Image.network(
                              'https://openweathermap.org/img/wn/${h.icon}.png',
                              height: 36,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.cloud,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${h.temperature.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ==========================================================
                // 7-DAY FORECAST
                // ==========================================================
                _sectionTitle('7-Day Forecast'),
                const SizedBox(height: 8),
                Column(
                  children: weather.daily.map((d) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: _card(
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              d.dayName,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            Image.network(
                              'https://openweathermap.org/img/wn/${d.icon}.png',
                              height: 36,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.cloud,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${d.minTemp.toStringAsFixed(0)}° / ${d.maxTemp.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(text,
              style:
                  const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
