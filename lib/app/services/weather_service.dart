import 'dart:convert';
import 'dart:io';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.weatherCode,
    required this.isDay,
    required this.temperatureCelsius,
  });

  final int weatherCode;
  final bool isDay;
  final double temperatureCelsius;
}

class WeatherService {
  Future<WeatherSnapshot> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'weather_code,is_day,temperature_2m',
      'timezone': 'auto',
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Weather API request failed with status ${response.statusCode}.',
          uri: uri,
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) {
        throw const FormatException('Missing current weather data.');
      }

      return WeatherSnapshot(
        weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
        isDay: ((current['is_day'] as num?)?.toInt() ?? 1) == 1,
        temperatureCelsius:
            (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      );
    } finally {
      client.close(force: true);
    }
  }
}
