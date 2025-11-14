// lib/services/weather_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 🔑 Your OpenWeatherMap API key
const String _apiKey = "889ee4eed76370fdee9184b641e34929";

/// -----------------------------
/// MODELS
/// -----------------------------
class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String icon;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.icon,
  });

  String get hourLabel => DateFormat('HH:mm').format(time);
}

class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final String icon;
  final DateTime sunrise;
  final DateTime sunset;

  DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.icon,
    required this.sunrise,
    required this.sunset,
  });

  String get dayName => DateFormat('EEE').format(date);
}

class WeatherData {
  final String city;
  final String state;
  final String country;

  final double temperature;
  final double feelsLike;
  final String description;
  final int humidity;
  final double windSpeed;
  final String icon;

  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  WeatherData({
    required this.city,
    required this.state,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.icon,
    required this.hourly,
    required this.daily,
  });
}

/// -----------------------------
/// WEATHER SERVICE (FREE API)
/// -----------------------------
class WeatherService {
  Future<WeatherData?> fetchWeather(double lat, double lon) async {
    try {
      // -------------------------------
      // 1) Fetch CURRENT WEATHER
      // -------------------------------
      final currentUrl =
          "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric";

      final currentRes = await http.get(Uri.parse(currentUrl));
      if (currentRes.statusCode != 200) {
        print("❌ Current Weather Error: ${currentRes.body}");
        return null;
      }
      final currentJson = jsonDecode(currentRes.body);

      // -------------------------------
      // 2) Fetch 5-DAY (3-HOUR) FORECAST
      // -------------------------------
      final forecastUrl =
          "https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric";

      final forecastRes = await http.get(Uri.parse(forecastUrl));
      if (forecastRes.statusCode != 200) {
        print("❌ Forecast Error: ${forecastRes.body}");
        return null;
      }
      final forecastJson = jsonDecode(forecastRes.body);
      final List<dynamic> list = forecastJson["list"];

      // -------------------------------
      // 3) Reverse Geocode → readable city
      // -------------------------------
      final geoUrl =
          "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json";

      final geoRes = await http.get(
        Uri.parse(geoUrl),
        headers: {'User-Agent': "MyNotesApp/1.0"},
      );

      String city = "Unknown";
      String state = "";
      String country = "";

      if (geoRes.statusCode == 200) {
        final geoJson = jsonDecode(geoRes.body);
        final addr = geoJson["address"] ?? {};
        city = addr["city"] ??
            addr["town"] ??
            addr["village"] ??
            addr["county"] ??
            "Unknown";

        state = addr["state"] ?? "";
        country = addr["country"] ?? "";
      }

      // -------------------------------
      // Build RAW HOURLY (3-hour data)
      // -------------------------------
      final rawHourly = list.take(8).map((item) {
        final dt = DateTime.fromMillisecondsSinceEpoch(item["dt"] * 1000);
        return HourlyForecast(
          time: dt,
          temperature: (item["main"]["temp"] as num).toDouble(),
          icon: item["weather"][0]["icon"],
        );
      }).toList();

      // -------------------------------
      // Construct HOURLY → INTERPOLATED (EVERY HOUR)
      // -------------------------------
      final List<HourlyForecast> expanded = [];

      for (int i = 0; i < rawHourly.length - 1; i++) {
        final current = rawHourly[i];
        final next = rawHourly[i + 1];

        expanded.add(current);

        final diff = next.time.difference(current.time).inHours;
        if (diff > 1) {
          final tempStep =
              (next.temperature - current.temperature) / diff;

          // Add missing hours
          for (int h = 1; h < diff; h++) {
            expanded.add(
              HourlyForecast(
                time: current.time.add(Duration(hours: h)),
                temperature:
                    current.temperature + tempStep * h,
                icon: current.icon, // keep icon simple
              ),
            );
          }
        }
      }

      // add final
      expanded.add(rawHourly.last);

      // Keep next 24 hours only
      final now = DateTime.now();
      final next24 = expanded.where((e) =>
          e.time.isAfter(now) &&
          e.time.isBefore(now.add(const Duration(hours: 24)))).toList();

      final hourly = next24;

      // -------------------------------
      // Build DAILY
      // -------------------------------
      final Map<String, List<dynamic>> days = {};

      for (var item in list) {
        final dt = DateTime.fromMillisecondsSinceEpoch(item["dt"] * 1000);
        final key = "${dt.year}-${dt.month}-${dt.day}";
        days.putIfAbsent(key, () => []);
        days[key]!.add(item);
      }

      final List<DailyForecast> daily = days.entries.map((entry) {
        final values = entry.value;

        final temps = values.map((v) => (v["main"]["temp"] as num).toDouble());
        final icons = values.map((v) => v["weather"][0]["icon"]);

        final dt =
            DateTime.fromMillisecondsSinceEpoch(values.first["dt"] * 1000);

        return DailyForecast(
          date: dt,
          minTemp: temps.reduce((a, b) => a < b ? a : b),
          maxTemp: temps.reduce((a, b) => a > b ? a : b),
          icon: icons.first,
          sunrise: DateTime.fromMillisecondsSinceEpoch(
              currentJson["sys"]["sunrise"] * 1000),
          sunset: DateTime.fromMillisecondsSinceEpoch(
              currentJson["sys"]["sunset"] * 1000),
        );
      }).take(7).toList();

      // -------------------------------
      // Build FINAL WeatherData
      // -------------------------------
      return WeatherData(
        city: city,
        state: state,
        country: country,
        temperature: (currentJson["main"]["temp"] as num).toDouble(),
        feelsLike: (currentJson["main"]["feels_like"] as num).toDouble(),
        description: currentJson["weather"][0]["description"],
        humidity: currentJson["main"]["humidity"],
        windSpeed: (currentJson["wind"]["speed"] as num).toDouble(),
        icon: currentJson["weather"][0]["icon"],
        hourly: hourly,
        daily: daily,
      );
    } catch (e) {
      print("❌ WeatherService Exception: $e");
      return null;
    }
  }
}
