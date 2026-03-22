import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/home_weather_state.dart';
import '../services/weather_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({WeatherService? weatherService})
      : _weatherService = weatherService ?? WeatherService(),
        _state = HomeWeatherState.loading();

  final WeatherService _weatherService;

  HomeWeatherState _state;
  HomeWeatherState get state => _state;

  Future<void> load() async {
    _state = HomeWeatherState.loading();
    notifyListeners();

    final hour = DateTime.now().hour;
    final fallbackGreeting = _greetingForHour(hour);
    final fallbackMessage = _fallbackMessageForHour(hour);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _state = HomeWeatherState(
          greeting: fallbackGreeting,
          message: fallbackMessage,
          isLoading: false,
          icon: _fallbackIconForHour(hour),
        );
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _state = HomeWeatherState(
          greeting: fallbackGreeting,
          message: fallbackMessage,
          isLoading: false,
          icon: _fallbackIconForHour(hour),
        );
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final snapshot = await _weatherService.fetchCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _state = HomeWeatherState(
        greeting: _greetingForHour(hour),
        message: _messageForWeather(
          weatherCode: snapshot.weatherCode,
          isDay: snapshot.isDay,
          hour: hour,
        ),
        isLoading: false,
        icon: _iconForWeather(
          weatherCode: snapshot.weatherCode,
          isDay: snapshot.isDay,
          hour: hour,
        ),
      );
    } catch (_) {
      _state = HomeWeatherState(
        greeting: fallbackGreeting,
        message: fallbackMessage,
        isLoading: false,
        icon: _fallbackIconForHour(hour),
      );
    }

    notifyListeners();
  }

  String _greetingForHour(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _fallbackMessageForHour(int hour) {
    if (hour < 12) return 'Ready to build today\'s look?';
    if (hour < 18) return 'A fresh outfit idea is ready for you.';
    return 'Set up something polished for tonight.';
  }

  IconData _fallbackIconForHour(int hour) {
    if (hour >= 18 || hour < 5) {
      return Icons.nightlight_round;
    }
    return Icons.wb_sunny_outlined;
  }

  String _messageForWeather({
    required int weatherCode,
    required bool isDay,
    required int hour,
  }) {
    if (_isRainy(weatherCode)) return 'Grab your coat today.';
    if (_isSnowy(weatherCode)) return 'Layer up, it looks chilly out.';
    if (_isStormy(weatherCode)) return 'Stormy skies today, dress for the weather.';
    if (_isFoggy(weatherCode)) return 'A misty day calls for easy layers.';
    if (_isCloudy(weatherCode)) {
      return isDay
          ? 'A light layer will keep you comfortable.'
          : 'Cloudy tonight, keep something cozy nearby.';
    }
    if (_isClear(weatherCode)) {
      if (hour < 12) return 'Sun\'s out, stay cool!';
      if (hour < 18) return 'Bright skies today, keep it light.';
      return 'Clear evening ahead, dress sharp.';
    }

    return _fallbackMessageForHour(hour);
  }

  IconData _iconForWeather({
    required int weatherCode,
    required bool isDay,
    required int hour,
  }) {
    if (_isStormy(weatherCode)) return Icons.thunderstorm_rounded;
    if (_isRainy(weatherCode)) return Icons.umbrella_rounded;
    if (_isSnowy(weatherCode)) return Icons.ac_unit_rounded;
    if (_isFoggy(weatherCode)) return Icons.blur_on_rounded;
    if (_isCloudy(weatherCode)) {
      return isDay ? Icons.cloud_outlined : Icons.cloud_rounded;
    }
    if (_isClear(weatherCode)) {
      if (!isDay || hour >= 18 || hour < 5) {
        return Icons.nightlight_round;
      }
      return Icons.wb_sunny_outlined;
    }

    return _fallbackIconForHour(hour);
  }

  bool _isClear(int code) => code == 0 || code == 1;
  bool _isCloudy(int code) => code == 2 || code == 3;
  bool _isFoggy(int code) => code == 45 || code == 48;
  bool _isRainy(int code) =>
      {51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82}.contains(code);
  bool _isSnowy(int code) => {71, 73, 75, 77, 85, 86}.contains(code);
  bool _isStormy(int code) => {95, 96, 99}.contains(code);
}
