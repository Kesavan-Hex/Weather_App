import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

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

// Define a new class to represent the daily weather forecast.
class DailyWeather {
  final DateTime date;
  final double maxTemperature;
  final double minTemperature;
  final String icon;

  DailyWeather({
    required this.date,
    required this.maxTemperature,
    required this.minTemperature,
    required this.icon,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  TextEditingController _cityController = TextEditingController();
  List<DailyWeather>? dailyWeather;
  String? currentLocation;
  bool hasInternet = true;
  Map<String, dynamic>? weatherData;
  bool isCelsius = true;
  String? _searchError;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

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
      fetchWeatherData(position.latitude, position.longitude);
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
      fetchWeatherData(position.latitude, position.longitude);
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
    final apiKey = 'YOUR_OWM_API';
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          weatherData = jsonData;
          _searchError = null; // Clear any previous error
        });

        // Pass the city information to fetchSevenDayForecastFromCity
        final city = jsonData["name"];
        fetchSevenDayForecastFromCity(city);
      } else {
        // Handle error
        setState(() {
          _searchError = 'City not found'; // Set the error message
        });
        print('Failed to fetch weather data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      setState(() {
        _searchError = 'Error fetching weather data';
      });
      print('Error fetching weather data: $e');
    }
  }

  Future<void> fetchSevenDayForecastFromCity(String city) async {
    final apiKey =
        'YOUR_OWM_API'; // Replace with your API key
    final url = 'https://api.openweathermap.org/data/2.5/onecall?' +
        'q=$city&exclude=current,hourly,minutely,alerts&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final dailyData = jsonData['daily'];

        List<DailyWeather> forecast = [];

        for (var day in dailyData) {
          forecast.add(DailyWeather(
            date: DateTime.fromMillisecondsSinceEpoch(day['dt'] * 1000),
            maxTemperature: (day['temp']['max'] - 273.15),
            minTemperature: (day['temp']['min'] - 273.15),
            icon: day['weather'][0]['icon'],
          ));

          // Print details to log
          print(
              'Date: ${DateTime.fromMillisecondsSinceEpoch(day['dt'] * 1000)}');
          print('Max Temperature: ${day['temp']['max'] - 273.15}°C');
          print('Min Temperature: ${day['temp']['min'] - 273.15}°C');
          print('Icon: ${day['weather'][0]['icon']}');
        }

        setState(() {
          dailyWeather = forecast;
        });
      } else {
        print('Failed to fetch 7-day forecast: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching 7-day forecast: $e');
    }
  }

  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void toggleTemperatureUnit() {
    setState(() {
      isCelsius = !isCelsius;
    });
  }

  Widget buildTemperature(String temperature, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 40,
          color: Colors.blue,
        ),
        Text(
          '$temperature',
          style: TextStyle(fontSize: 24),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 18),
        ),
      ],
    );
  }

  Widget buildWeatherDetails() {
    if (weatherData == null) {
      return Container();
    }

    final mainWeather = weatherData!["weather"][0];
    final mainInfo = weatherData!["main"];
    final windInfo = weatherData!["wind"];

    double temperature = mainInfo["temp"] - 273.15;
    double maxTemperature = mainInfo["temp_max"] - 273.15;
    double minTemperature = mainInfo["temp_min"] - 273.15;

    if (!isCelsius) {
      temperature = (temperature * 9 / 5) + 32;
      maxTemperature = (maxTemperature * 9 / 5) + 32;
      minTemperature = (minTemperature * 9 / 5) + 32;
    }

    final cloudIcon = mainWeather["icon"];
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
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildTemperature(
              '${temperature.toStringAsFixed(2)}${isCelsius ? '°C' : '°F'}',
              'Temperature',
              Icons.thermostat,
            ),
            buildTemperature(
              '${maxTemperature.toStringAsFixed(2)}${isCelsius ? '°C' : '°F'}',
              'Max Temp',
              Icons.arrow_upward,
            ),
            buildTemperature(
              '${minTemperature.toStringAsFixed(2)}${isCelsius ? '°C' : '°F'}',
              'Min Temp',
              Icons.arrow_downward,
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildTemperature(
              formatTime(sunrise),
              'Sunrise',
              Icons.wb_sunny,
            ),
            buildTemperature(
              formatTime(sunset),
              'Sunset',
              Icons.nightlight_round,
            ),
          ],
        ),
        SizedBox(height: 15),
        ElevatedButton(
          onPressed: toggleTemperatureUnit,
          child: Text(isCelsius ? 'Switch to °F' : 'Switch to °C'),
        ),
        SizedBox(height: 15),
        Card(
          color: Colors.lightBlue[100],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 24,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Visibility:',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          size: 24,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Wind Speed:',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.water,
                          size: 24,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Humidity:',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${weatherData!["visibility"]} meters',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '${windInfo["speed"]} m/s',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '${mainInfo["humidity"]}',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.opacity,
                          size: 24,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Sea Level:',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.terrain,
                          size: 24,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Ground Level:',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${mainInfo["sea_level"]} hPa',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '${mainInfo["grnd_level"]} hPa',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  void handleSearch() {
    final city = _cityController.text;
    if (city.isNotEmpty) {
      fetchWeatherDataByCity(city);
    }
  }

  Future<void> fetchWeatherDataByCity(String city) async {
    final apiKey = 'YOUR_OWM_API';
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          weatherData = jsonData;
          _searchError = null; // Clear any previous error
        });
        _scaffoldKey.currentState!
            .openEndDrawer(); // Close the drawer on sucess search
      } else {
        // Handle error
        setState(() {
          _searchError = 'City not found'; // Set the error message
        });
        print('Failed to fetch weather data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      setState(() {
        _searchError = 'Error fetching weather data';
      });
      print('Error fetching weather data: $e');
    }
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            buildWeatherDetails(),
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
                controller: _cityController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  hintText: 'Search...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: handleSearch, // Call handleSearch function
                  ),
                ),
              ),
            ),
            if (_searchError != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _searchError!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
