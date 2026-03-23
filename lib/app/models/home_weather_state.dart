import 'package:flutter/material.dart';

class HomeWeatherState {
  const HomeWeatherState({
    required this.greeting,
    required this.message,
    required this.isLoading,
    required this.icon,
    required this.temperatureLabel,
    required this.shouldSuggestOuterwear,
  });

  final String greeting;
  final String message;
  final bool isLoading;
  final IconData icon;
  final String? temperatureLabel;
  final bool shouldSuggestOuterwear;

  factory HomeWeatherState.loading() {
    return const HomeWeatherState(
      greeting: 'Hello',
      message: 'Checking your local weather...',
      isLoading: true,
      icon: Icons.sync_rounded,
      temperatureLabel: null,
      shouldSuggestOuterwear: false,
    );
  }
}
