import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Menggambar Karakter',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const DrawingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({Key? key}) : super(key: key);

  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late final ScribbleNotifier notifier;
  String _feedback = "Gambar dan kirim untuk dapat feedback.";
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    notifier = ScribbleNotifier();

    notifier.setColor(Colors.white);
    notifier.setStrokeWidth(15);
  }

  Future<void> _sendCoordinatesToBackend() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _feedback = "Mengirim dan memproses...";
    });

    final lines = notifier.value.lines;

    if (lines.isEmpty) {
      setState(() {
        _feedback = "Silakan gambar sesuatu terlebih dahulu.";
        _isSending = false;
      });
      return;
    }

    final canvasSize = (context.findRenderObject() as RenderBox).size;

    final List<List<Map<String, double>>> coordinates = lines
        .map((line) =>
        line.points.map((point) => {'x': point.x, 'y': point.y}).toList())
        .toList();
    var url = Uri.parse('http://10.0.2.2:3000/predict');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(<String, dynamic>{
          'strokes': coordinates,
          'canvasWidth': canvasSize.width,
          'canvasHeight': canvasSize.height,
          'targetCharacter': 'Alif'
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          _feedback = "Prediksi: ${responseData['prediction']}\nKeyakinan: ${responseData['confidence']}%";
        });
      } else {
        setState(() {
          _feedback = "Error: Server merespons dengan status ${response.statusCode}.";
        });
      }
    } catch (e) {
      setState(() {
        _feedback = "Error: Tidak dapat terhubung ke server. Pastikan server berjalan dan IP sudah benar.";
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
      appBar: AppBar(title: const Text("Gambar Karakter")),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Scribble(
                notifier: notifier,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _feedback,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isSending ? null : _sendCoordinatesToBackend,
                  child: _isSending ? const CircularProgressIndicator(color: Colors.white,) : const Text("Kirim Prediksi"),
                ),
                ElevatedButton(
                  onPressed: () {
                    notifier.clear();
                    setState(() {
                      _feedback = "Gambar dan kirim untuk dapat feedback.";
                    });
                  },
                  child: const Text("Bersihkan"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}