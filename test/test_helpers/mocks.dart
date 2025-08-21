import 'package:mockito/annotations.dart';
import 'package:heads_up_game/services/audio_service.dart';
import 'package:heads_up_game/services/haptic_service.dart';
import 'package:heads_up_game/services/firebase_service.dart';
import 'package:heads_up_game/services/deck_firebase_service.dart';
import 'package:heads_up_game/services/game_firebase_service.dart';
import 'package:heads_up_game/providers/deck_provider.dart';
import 'package:heads_up_game/providers/game_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Generate mocks using: dart run build_runner build
@GenerateMocks([
  AudioService,
  HapticService,
  FirebaseService,
  DeckFirebaseService,
  GameFirebaseService,
  DeckProvider,
  GameProvider,
  AudioPlayer,
  SharedPreferences,
  FirebaseFirestore,
  FirebaseAuth,
  User,
  UserCredential,
])
void main() {}

