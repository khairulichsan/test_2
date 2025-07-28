import 'package:cocoicons/cocoicons.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import 'dart:convert'; // Diperlukan untuk jsonEncode
import 'package:http/http.dart' as http; // Diperlukan untuk HTTP request

// --- DATA UNTUK HURUF HIJAIYAH ---
// Daftar huruf yang bisa dipilih
final List<String> hijaiyahLetters = [
  'Alif', 'Ba', 'Ta', 'Tsa', 'Jim', 'Ha', 'Kha', 'Dal', 'Dzal',
  'Ra', 'Zay', 'Sin', 'Syin', 'Shad', 'Dhad', 'Tha', 'Zha', 'Ain',
  'Ghain', 'Fa', 'Qaf', 'Kaf', 'Lam', 'Mim', 'Nun', 'Waw', 'Ha', 'Ya'
];

// Mapping nama huruf ke path gambar asetnya.
// GANTI path ini sesuai dengan nama file gambar Anda.
final Map<String, String> letterImageAssets = {
  'Alif': 'assets/images/alif.png',
  'Ba': 'assets/images/ba.png',
  'Ta': 'assets/images/ta.png',
  'Jim': 'assets/images/jim.png',
  // ...Lengkapi untuk semua huruf...
  'Ya': 'assets/images/ya.png',
};


// --- PROVIDERS ---
final scribbleNotifierProvider =
ChangeNotifierProvider.autoDispose<ScribbleNotifier>(
      (ref) => ScribbleNotifier(
    widths: [15],
    allowedPointersMode: ScribblePointerMode.all,
    pressureCurve: Curves.easeIn,
  ),
);

// Provider untuk menyimpan huruf yang sedang dipilih
final selectedLetterProvider = StateProvider<String?>((ref) => null);

// Provider untuk menyimpan hasil prediksi
final predictionProvider = StateProvider<String>((ref) => "Pilih huruf untuk memulai.");


class CustomColors {
  static const Color neutralGray = Colors.grey;
}

TextStyle customStyle(BuildContext context, String type) {
  return Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
}

class ScribbleTestPage extends ConsumerStatefulWidget {
  const ScribbleTestPage({super.key});

  @override
  ConsumerState<ScribbleTestPage> createState() => _ScribbleTestPageState();
}

class _ScribbleTestPageState extends ConsumerState<ScribbleTestPage> {
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scribbleNotifierProvider).setColor(Colors.white);
    });
  }

  void debugLog(String message) {
    developer.log(message, name: 'ScribbleTestPage');
  }

  Future<void> _sendSketchToBackend() async {
    final scribbleNotifier = ref.read(scribbleNotifierProvider);
    final sketch = scribbleNotifier.currentSketch;
    final selectedLetter = ref.read(selectedLetterProvider);

    if (selectedLetter == null) {
      ref.read(predictionProvider.notifier).state = "Pilih huruf terlebih dahulu.";
      return;
    }

    if (sketch.lines.isEmpty) {
      ref.read(predictionProvider.notifier).state = "Silakan gambar terlebih dahulu.";
      return;
    }

    final RenderBox? renderBox =
    _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      ref.read(predictionProvider.notifier).state = "Error: Tidak bisa mendapatkan ukuran canvas.";
      return;
    }
    final canvasSize = renderBox.size;

    ref.read(predictionProvider.notifier).state = "Memvalidasi tulisan...";

    final List<List<Map<String, double>>> strokesForJson = sketch.lines
        .map((line) =>
        line.points.map((p) => {'x': p.x, 'y': p.y}).toList())
        .toList();

    final body = {
      'strokes': strokesForJson,
      'canvasWidth': canvasSize.width,
      'canvasHeight': canvasSize.height,
      'targetLetter': selectedLetter,
    };
    debugLog("lebar ${canvasSize.width}");
    debugLog("tinggi ${canvasSize.height}");

    final url = Uri.parse('http://10.0.2.2:3000/predict');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final target = responseBody['target'];
        final similarity = responseBody['similarity'];

        String resultText = "Kemiripan dengan '$target': $similarity%";

        if (similarity >= 70) {
          resultText += "\nBagus sekali! 👍";
        } else if (similarity >= 40) {
          resultText += "\nSudah cukup baik, sedikit lagi! 👌";
        } else {
          resultText += "\nCoba lagi, Anda pasti bisa! 👎";
        }
        ref.read(predictionProvider.notifier).state = resultText;
      } else {
        ref.read(predictionProvider.notifier).state =
        "Error: ${response.statusCode}\n${response.body}";
      }
    } catch (e) {
      ref.read(predictionProvider.notifier).state = "Error: Gagal terhubung ke server.\n$e";
      debugLog("Error sending sketch: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scribbleNotifier = ref.watch(scribbleNotifierProvider);
    final predictionResult = ref.watch(predictionProvider);
    final selectedLetter = ref.watch(selectedLetterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latihan Menulis Hijaiyah'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButton<String>(
                  value: selectedLetter,
                  isExpanded: true,
                  hint: const Text("Pilih Huruf"),
                  items: hijaiyahLetters.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 20)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    ref.read(selectedLetterProvider.notifier).state = newValue;
                    scribbleNotifier.clear();
                    ref.read(predictionProvider.notifier).state = "Tiru contoh di atas.";
                  },
                ),
              ),

              // --- PERUBAHAN UTAMA: Layout diubah menjadi Column (atas-bawah) ---

              // 1. Contoh Gambar di bagian atas
              if (selectedLetter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 100, // Tinggi area contoh
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200,
                    ),
                    child: Center(
                      child: (letterImageAssets.containsKey(selectedLetter))
                          ? Image.asset(
                        letterImageAssets[selectedLetter]!,
                        fit: BoxFit.contain,
                      )
                          : const Text("Contoh tidak ditemukan", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ),

              if (selectedLetter != null)
                const SizedBox(height: 16), // Spasi antara contoh dan kanvas

              // 2. Kanvas Gambar yang lebih luas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AspectRatio(
                  // --- PERUBAHAN: Rasio diubah menjadi 1/1 untuk bentuk persegi ---
                  aspectRatio: 1 / 1,
                  child: Container(
                    key: _canvasKey,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black,
                    ),
                    child: Scribble(
                      notifier: scribbleNotifier,
                      drawPen: true,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  predictionResult,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      scribbleNotifier.clear();
                      ref.read(predictionProvider.notifier).state = "Tiru contoh di atas.";
                    },
                    icon: const Icon(CocoIconBold.Rotate_Left),
                    label: Text('ulangi'.i18n()),
                  ),
                  ElevatedButton.icon(
                    onPressed: selectedLetter == null ? null : _sendSketchToBackend,
                    icon: const Icon(Icons.check),
                    label: Text('check'.i18n()),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
