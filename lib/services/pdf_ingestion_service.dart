import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PDFIngestionService {
  /// Ingest local curriculum PDFs using Cloud Function
  static Future<Map<String, dynamic>> ingestLocalPDFs() async {
    try {
      debugPrint('Calling ingestLocalPDFs Cloud Function...');

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable = functions.httpsCallable(
        'ingestLocalPDFs',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 10), // PDFs take longer to process
        ),
      );

      final result = await callable.call(<String, dynamic>{});

      debugPrint('PDF ingestion completed successfully');
      return {
        'success': true,
        'message': result.data['status'] == 'ok'
            ? 'Successfully processed ${result.data['processed']} PDFs'
            : 'PDF ingestion completed',
        'processed': result.data['processed'] ?? 0,
        'results': result.data['results'] ?? [],
      };

    } catch (e) {
      debugPrint('Error calling PDF ingestion function: $e');

      String errorMessage = 'Failed to ingest PDFs';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please ensure you are logged in as an admin.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'PDF ingestion timed out. The process may still be running in the background.';
      } else {
        errorMessage = 'Failed to ingest PDFs: ${e.toString()}';
      }

      return {
        'success': false,
        'message': errorMessage,
        'processed': 0,
        'results': [],
      };
    }
  }

  /// List available PDFs and their ingestion status
  static Future<Map<String, dynamic>> listPDFs() async {
    try {
      debugPrint('Calling listPDFs Cloud Function...');

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final HttpsCallable callable = functions.httpsCallable('listPDFs');

      final result = await callable.call(<String, dynamic>{});

      debugPrint('PDF list retrieved successfully');
      return {
        'success': true,
        'message': 'PDF status retrieved successfully',
        'pdfs': result.data['pdfs'] ?? [],
      };

    } catch (e) {
      debugPrint('Error calling listPDFs function: $e');

      return {
        'success': false,
        'message': 'Failed to retrieve PDF status: ${e.toString()}',
        'pdfs': [],
      };
    }
  }
}