import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scribble/scribble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- TAMBAHKAN INI ---
// Impor file halaman tes Anda. Pastikan nama file sudah benar.
import 'test-scribble.dart';

void main() {
  runApp(const ProviderScope(
    child: MyApp(), // Ganti MyApp() jika nama widget utama Anda berbeda
  ));
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
  final double canvasSize = 300.0;

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

    final List<List<Map<String, double>>> coordinates = lines
        .map((line) =>
        line.points.map((point) => {'x': point.x, 'y': point.y}).toList())
        .toList();

    var url = Uri.parse('http://10.0.2.2:3000/predict');

    try {
      var response = await http
          .post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(<String, dynamic>{
          'strokes': coordinates,
          'canvasWidth': canvasSize,
          'canvasHeight': canvasSize,
          'targetCharacter': 'Kaf'
        }),
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          _feedback =
          "Hasil: ${responseData['feedback']}\nKeyakinan: ${responseData['confidence']}%";
        });
      } else {
        setState(() {
          _feedback =
          "Error: Server merespons (Status: ${response.statusCode}).";
        });
      }
    } catch (e) {
      setState(() {
        _feedback = "Error: Tidak dapat terhubung ke server.";
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
      body: Center(
        child: SingleChildScrollView( // Membungkus dengan SingleChildScrollView
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: canvasSize,
                height: canvasSize,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.blueGrey, width: 2),
                  ),
                  child: Scribble(
                    notifier: notifier,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _feedback,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendCoordinatesToBackend,
                    child: _isSending
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text("Kirim Prediksi"),
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
              const SizedBox(height: 10),
              // --- TOMBOL BARU DITAMBAHKAN DI SINI ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                ),
                onPressed: () {
                  // Navigasi ke halaman ScribbleTestPage saat tombol ditekan
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScribbleTestPage()),
                  );
                },
                child: const Text("Buka Halaman Tes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
