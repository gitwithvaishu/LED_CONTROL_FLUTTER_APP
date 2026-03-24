import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LedTogglePage(),
    );
  }
}

class LedTogglePage extends StatefulWidget {
  const LedTogglePage({super.key});

  @override
  State<LedTogglePage> createState() => _LedTogglePageState();
}

class _LedTogglePageState extends State<LedTogglePage> {
  bool isOn = false;
  bool isLoading = false;
  bool isConnected = true;

  String espStatusMessage = "Waiting for ESP8266...";

  late WebSocketChannel channel;


  final String baseUrl = "https://led-control-flutter-app.onrender.com";
  final String wsUrl = "ws://led-control-flutter-app.onrender.com";

  @override
  void initState() {
    super.initState();
    connectWebSocket();
  }

  
  void connectWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Register Flutter
    channel.sink.add(jsonEncode({"type": "flutter"}));

    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);

        if (data['type'] == 'update') {
          setState(() {
            isOn = data['led'];
            espStatusMessage = data['message'];
            // isConnected = true;

            
          });
        }

        if(data['type'] == 'esp_status'){
          setState((){
            isConnected = data['connected'];
            espStatusMessage = data['message'];

            if(!data['connected']){
              isOn = false;
            }
          });
        }
      },
      onError: (error) {
        setState(() {
          isConnected = false;
          espStatusMessage = "WebSocket Error";
          isOn = false;
        });
        reconnect();
      },
      onDone: () {
        setState(() {
          isConnected = false;
          espStatusMessage = "Disconnected";
          isOn = false;
        });
        reconnect();
      },
    );
  }

  
  void reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      connectWebSocket();
    });
  }

 
  Future<void> toggleLED(bool value) async {
    if (isLoading || !isConnected) return;

    setState(() {
      isLoading = true;
      isOn = value; // optimistic UI
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/toggle"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"led": value}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data["message"]);
      }

      setState(() {
        espStatusMessage = data["message"];
      });

    } catch (e) {
      setState(() {
        espStatusMessage = "Server Error";
        isOn = !value; // rollback
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: isOn
                      ? Colors.green.withOpacity(0.6)
                      : Colors.red.withOpacity(0.6),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn ? Colors.green : Colors.red,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  isOn ? "LED is ON" : "LED is OFF",
                  style: TextStyle(
                    fontSize: 24,
                    color: isOn ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                
                Switch(
                  value: isOn,
                  onChanged: isLoading ? null : toggleLED,
                ),

                const SizedBox(height: 20),

                
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isConnected ? "ESP8266 CONNECTED" : "ESP8266 DISCONNECTED",
                        style: TextStyle(
                          color:
                              isConnected ? Colors.green : Colors.red,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        espStatusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                
                if (isLoading)
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}