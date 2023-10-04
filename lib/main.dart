import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Forecast',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 155, 194, 252)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Weather Forecast'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? currentLocation;
  bool hasInternet = true;
  Map<String, dynamic>? weatherData;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      checkInternetConnectivity();
      requestLocationPermission();
    } else {
      getCurrentLocationWeb();
    }
  }

  Future<void> checkInternetConnectivity() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'));
      setState(() {
        hasInternet = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        hasInternet = false;
      });
    }

    if (!hasInternet) {
      showInternetPopup();
    }
  }

  Future<void> requestLocationPermission() async {
    if (!kIsWeb) {
      final status = await Permission.location.request();
      if (status.isGranted) {
        getCurrentLocation();
      } else if (status.isDenied) {
        showLocationPermissionDeniedDialog();
      }
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentLocation =
            'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
        fetchWeatherData(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void showLocationPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text(
              'Please grant location permission to access your current location.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> getCurrentLocationWeb() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentLocation =
            'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
        fetchWeatherData(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location on web: $e');
    }
  }

  void showInternetPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Internet Connection Required'),
          content: Text('Please check your internet connection and try again.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> fetchWeatherData(double latitude, double longitude) async {
    final apiKey = 'dbf8210447f99f7efc0d4457ec4c1917';
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          weatherData = jsonData;
        });
      } else {
        // Handle error
        print('Failed to fetch weather data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error fetching weather data: $e');
    }
  }

  // Widget to display weather details
  Widget buildWeatherDetails() {
    if (weatherData == null) {
      return Container();
    }

    final mainWeather = weatherData!["weather"][0];
    final mainInfo = weatherData!["main"];
    final windInfo = weatherData!["wind"];

    // Convert temperature from Kelvin to Celsius
    final double temperatureInKelvin = mainInfo["temp"];
    final double temperatureInCelsius = temperatureInKelvin - 273.15;

    // Get the cloud icon based on weather condition
    final cloudIcon = mainWeather["icon"];

    // Convert sunrise and sunset times to 12-hour format
    final sunrise = DateTime.fromMillisecondsSinceEpoch(
        weatherData!["sys"]["sunrise"] * 1000);
    final sunset = DateTime.fromMillisecondsSinceEpoch(
        weatherData!["sys"]["sunset"] * 1000);

    return Column(
      children: [
        Text(
          '${weatherData!["name"]}, ${weatherData!["sys"]["country"]}',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Image.network(
              'https://openweathermap.org/img/wn/$cloudIcon.png',
              width: 50,
              height: 50,
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sunrise: ${DateFormat('hh:mm a').format(sunrise)}',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  'Sunset: ${DateFormat('hh:mm a').format(sunset)}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                // Implement temperature conversion to Fahrenheit here
              },
              child: Text('Convert to Fahrenheit'),
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temperature: ${temperatureInCelsius.toStringAsFixed(2)}°C',
                  style: TextStyle(fontSize: 24),
                ),
                Text(
                  'Max Temp: ${mainInfo["temp_max"].toStringAsFixed(2)}°C',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  'Min Temp: ${mainInfo["temp_min"].toStringAsFixed(2)}°C',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),
        Card(
          color: Colors.lightBlue[100],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visibility: ${weatherData!["visibility"]} meters',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  'Wind Speed: ${windInfo["speed"]} m/s',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  'Humidity: ${mainInfo["humidity"]}%',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  'Sea Level: ${mainInfo["sea_level"]} hPa',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  'Ground Level: ${mainInfo["grnd_level"]} hPa',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState!.openDrawer();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (currentLocation != null)
              Text(
                'Current Location: $currentLocation',
                style: TextStyle(fontSize: 18),
              ),
            SizedBox(height: 20),
            buildWeatherDetails(), // Display weather details
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Image.asset(
                'assets/logo.png',
                width: 150,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  hintText: 'Search...',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
