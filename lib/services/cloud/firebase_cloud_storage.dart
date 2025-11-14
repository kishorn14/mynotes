// lib/services/cloud/firebase_cloud_storage.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mynotesapp/services/cloud/cloud_note.dart';
import 'package:mynotesapp/services/cloud/cloud_storage_constants.dart';
import 'package:mynotesapp/services/cloud/cloud_storage_exceptions.dart';

class FirebaseCloudStorage {
  final notes = FirebaseFirestore.instance.collection('notes');
  final uploads = FirebaseFirestore.instance.collection('uploads');
  final storage = FirebaseStorage.instance;

  // ✅ Upload photo + location to Firebase Storage + Firestore
  Future<void> uploadUserLocationAndImage({
    required String userId,
    required File imageFile,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Create a clean path in Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = storage.ref().child('user_uploads/$userId/$timestamp.jpg');

      print('📸 Uploading image to Firebase Storage...');

      // Upload the file
      final uploadTask = await ref.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Upload complete: $imageUrl');

      // Save metadata to Firestore
      await uploads.add({
        'userId': userId,
        'imageUrl': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('📍 Location uploaded for user: $userId');
    } catch (e) {
      print('❌ Error uploading image or location: $e');
      rethrow;
    }
  }

  // Notes management (unchanged)
  Future<void> deleteNote({required String documentId}) async {
    try {
      await notes.doc(documentId).delete();
    } catch (e) {
      throw CouldNotDeleteNoteException();
    }
  }

  Future<void> updateNote({
    required String documentId,
    required String text,
  }) async {
    try {
      await notes.doc(documentId).update({textFieldName: text});
    } catch (e) {
      throw CouldNotUpdateNoteException();
    }
  }

  Stream<Iterable<CloudNote>> allNotes({required String ownerUserId}) {
    final allNotes = notes
        .where(ownerUserIdFieldName, isEqualTo: ownerUserId)
        .snapshots()
        .map((event) => event.docs.map((doc) => CloudNote.fromSnapshot(doc)));
    return allNotes;
  }

  Future<CloudNote> createNewNote({required String ownerUserId}) async {
    final document = await notes.add({
      ownerUserIdFieldName: ownerUserId,
      textFieldName: '',
    });
    final fetchedNote = await document.get();
    return CloudNote(
      documentId: fetchedNote.id,
      ownerUserId: ownerUserId,
      text: '',
    );
  }

  static final FirebaseCloudStorage _shared =
      FirebaseCloudStorage._sharedInstance();
  FirebaseCloudStorage._sharedInstance();
  factory FirebaseCloudStorage() => _shared;
}
