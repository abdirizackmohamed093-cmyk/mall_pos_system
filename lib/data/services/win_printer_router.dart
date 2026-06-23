import 'dart:io';
import 'dart:typed_data';

class WinPrinterRouter {
  /// Sends raw ESC/POS bytes directly to a Windows hardware port.
  /// [printerName] must be the exact port string: 'USB001', 'LPT1', 'COM3', etc.
  /// Find it: Device Manager → Ports, or Printers → right-click → Properties → Ports tab.
  static Future<void> sendBytesToWindowsPrinter({
    required String printerName,
    required List<int> bytes,
  }) async {
    final payload = Uint8List.fromList(bytes);

    // ── Attempt 1: Direct port write (fastest, works on most USB thermal printers)
    try {
      final devicePort = File(printerName); // e.g. File('USB001')
      await devicePort.writeAsBytes(payload, flush: true);
      return; // ✅ success — exit here
    } catch (directWriteError) {
      // Direct write blocked (permissions or port type) — fall through to cmd copy
    }

    // ── Attempt 2: cmd /c copy /b via temp file (fallback for LPT/restricted ports)
    try {
      final tempFile = File('${Directory.systemTemp.path}\\pos_receipt_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(payload, flush: true);

      final result = await Process.run(
        'cmd',
        ['/c', 'copy', '/b', '"${tempFile.path}"', printerName],
        runInShell: true,
      );

      // Clean up temp file regardless of result
      if (await tempFile.exists()) await tempFile.delete();

      if (result.exitCode != 0) {
        throw Exception(
          'cmd copy failed (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (fallbackError) {
      throw Exception(
        'WinPrinterRouter: Both print methods failed.\n'
        'Port: $printerName\n'
        'Fallback error: $fallbackError\n'
        'Fix: Verify port name in Device Manager → Ports (COM & LPT)',
      );
    }
  }
}