import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

final String webhookUri = 'https://webhook.site/d1efe717-cdc1-4e9c-959a-4fe995502914';

// Definicje kolorów zgodne z identyfikacją wizualną SSPW
const Color primaryColor = Color(0xFF0073AA);
const Color secondaryColor = Color(0xFF005885);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define a custom orange color
    const Color customOrange = Color(0xFFFFA500); // Hex code for a vibrant orange

    return MaterialApp(
      theme: ThemeData(
        primaryColor: customOrange,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: customOrange,
          secondary: customOrange,
        ),
        fontFamily: 'Lato',
        // Additional theme settings
        appBarTheme: const AppBarTheme(
          backgroundColor: customOrange,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: customOrange,
          ),
        ),
      ),
      home: const GeolocationApp(),
    );
  }
}

class GeolocationApp extends StatefulWidget {
  const GeolocationApp({super.key});

  @override
  State<GeolocationApp> createState() => _GeolocationAppState();
}

class _GeolocationAppState extends State<GeolocationApp> {
  Position? _currentLocation;
  bool _isSending = false;
  String _statusMessage = 'Brak akcji';
  Color _statusColor = Colors.black;
  String? _lastSentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _getCurrentLocation());
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Pobieranie lokalizacji...';
      _statusColor = Colors.black;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isSending = false;
        _statusMessage = 'Usługi lokalizacyjne są wyłączone.';
        _statusColor = Colors.red;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isSending = false;
          _statusMessage = 'Brak uprawnień do lokalizacji.';
          _statusColor = Colors.red;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isSending = false;
        _statusMessage = 'Uprawnienia do lokalizacji są trwale odrzucone.';
        _statusColor = Colors.red;
      });
      return;
    }

    try {
        LocationSettings locationSettings = LocationSettings(
           accuracy: LocationAccuracy.high,
      );

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      setState(() {
        _currentLocation = position;
      });

      await _sendLocationData(position);
    } catch (e) {
      setState(() {
        _isSending = false;
        _statusMessage = 'Błąd podczas pobierania lokalizacji: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _sendLocationData(Position location) async {
    setState(() {
      _statusMessage = 'Wysyłanie danych...';
      _statusColor = Colors.black;
    });

    try {
      final response = await http.post(
        Uri.parse(webhookUri),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'longitude': location.longitude,
          'latitude': location.latitude,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Dane zostały pomyślnie wysłane.';
          _statusColor = Colors.green;
          _lastSentTime = DateTime.now().toLocal().toString();
        });
      } else {
        setState(() {
          _statusMessage = 'Błąd serwera: ${response.statusCode}';
          _statusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Błąd podczas wysyłania danych: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lokalizacja SSPW'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Aktualna lokalizacja',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _currentLocation != null
                ? Text(
                    'Szerokość Geograficzna: ${_currentLocation!.latitude}, Długość Geograficzna: ${_currentLocation!.longitude}',
                    style: const TextStyle(fontSize: 18),
                  )
                : const Text('Brak dostępnej lokalizacji'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSending ? null : _getCurrentLocation,
              child: const Text('Wyślij lokalizację'),
            ),
            const SizedBox(height: 20),
            Text(
              'Status: $_statusMessage',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: _statusColor),
            ),
            if (_lastSentTime != null) ...[
              const SizedBox(height: 10),
              Text('Ostatnia wysyłka: $_lastSentTime',
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
