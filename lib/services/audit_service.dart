import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuditService {
  /// Log an action performed on an item.
  ///
  /// Writes a document to the top-level `history` collection with fields:
  /// - `itemId`: id of the item
  /// - `action`: short action name (create/update/delete/status_change)
  /// - `user`: username performing the action (from SharedPreferences key `username`)
  /// - `details`: optional map with extra details
  /// - `timestamp`: server timestamp
  static Future<void> logItemHistory({
    required String itemId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = prefs.getString('username') ?? prefs.getString('nik') ?? 'unknown';

      final payload = <String, dynamic>{
        'itemId': itemId,
        'action': action,
        'user': user,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('history').add(payload);
    } catch (_) {
      // best-effort logging: swallow errors so UI flow isn't interrupted
    }
  }

  /// Log a general authentication event (login/logout)
  ///
  /// Writes to `history` collection with `eventType: 'auth'` and no `itemId`.
  static Future<void> logAuthEvent({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = prefs.getString('username') ?? prefs.getString('nik') ?? 'unknown';

      final payload = <String, dynamic>{
        'action': action,
        'user': user,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'auth',
      };

      await FirebaseFirestore.instance.collection('history').add(payload);
    } catch (_) {
      // swallow errors - best-effort
    }
  }
}
