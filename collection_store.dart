import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Live list of documents in users/{uid}/[path], kept in sync with Firestore.
/// Writes are not awaited: the snapshot listener updates the UI immediately
/// (including offline) and Firestore syncs in the background.
class CollectionStore<T> extends ChangeNotifier {
  CollectionStore({
    required this.path,
    required this.fromMap,
    required this.toMap,
    required this.idOf,
    required this.compare,
  });

  final String path;
  final T Function(String id, Map<String, dynamic> data) fromMap;
  final Map<String, dynamic> Function(T item) toMap;
  final String Function(T item) idOf;
  final int Function(T a, T b) compare;

  List<T> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool loading = false;
  String? error;

  /// Sorted using [compare].
  List<T> get items => List.unmodifiable(_items);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection(path);

  /// Call whenever the signed-in user changes (null = signed out).
  void bind(String? uid) {
    if (uid == _uid) return;
    _sub?.cancel();
    _sub = null;
    _uid = uid;
    _items = [];
    error = null;

    if (uid == null) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    _sub = _col!.snapshots().listen(
      (snap) {
        final list = <T>[];
        for (final d in snap.docs) {
          try {
            list.add(fromMap(d.id, d.data()));
          } catch (e) {
            debugPrint('Skipping bad $path/${d.id}: $e');
          }
        }
        list.sort(compare);
        _items = list;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('$path sync failed: $e');
        loading = false;
        error = 'Could not load data. Check your connection.';
        notifyListeners();
      },
    );
  }

  String newId() =>
      _col?.doc().id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Adds or replaces the document with the same id.
  void save(T item) => _write(() => _col?.doc(idOf(item)).set(toMap(item)));

  void delete(String id) => _write(() => _col?.doc(id).delete());

  void _write(Future<void>? Function() op) {
    op()?.catchError((Object e) {
      debugPrint('$path write failed: $e');
      error = 'Could not save your changes.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
