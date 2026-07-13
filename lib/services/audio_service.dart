import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, non-verbal audio identity for HELIX-9.
final class PromptHeistAudio extends ChangeNotifier {
  PromptHeistAudio._();

  static final instance = PromptHeistAudio._();
  static const _effectsKey = 'settings_effects_volume';
  static const _ambienceKey = 'settings_ambience_volume';
  static const _mutedKey = 'settings_audio_muted';
  static const _reducedMotionKey = 'settings_reduced_motion';

  double effectsVolume = .72;
  double ambienceVolume = .2;
  bool muted = false;
  bool reducedMotion = false;
  bool _loaded = false;
  bool _ambientPlaying = false;

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    effectsVolume = preferences.getDouble(_effectsKey) ?? effectsVolume;
    ambienceVolume = preferences.getDouble(_ambienceKey) ?? ambienceVolume;
    muted = preferences.getBool(_mutedKey) ?? muted;
    reducedMotion = preferences.getBool(_reducedMotionKey) ?? reducedMotion;
    _loaded = true;
  }

  Future<void> startAmbience() async {
    if (muted || ambienceVolume <= 0 || _ambientPlaying) return;
    _ambientPlaying = true;
    await FlameAudio.bgm.initialize();
    await FlameAudio.bgm.play('ambient_lab.wav', volume: ambienceVolume);
  }

  Future<void> stopAmbience() async {
    _ambientPlaying = false;
    await FlameAudio.bgm.stop();
  }

  Future<void> playEffect(String asset, {double gain = 1}) async {
    if (muted || effectsVolume <= 0) return;
    await FlameAudio.play(asset, volume: (effectsVolume * gain).clamp(0, 1));
  }

  Future<void> setMuted(bool value) async {
    muted = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_mutedKey, value);
    if (value) {
      await stopAmbience();
    } else {
      await startAmbience();
    }
  }

  Future<void> setEffectsVolume(double value) async {
    effectsVolume = value.clamp(0, 1);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_effectsKey, effectsVolume);
  }

  Future<void> setAmbienceVolume(double value) async {
    ambienceVolume = value.clamp(0, 1);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_ambienceKey, ambienceVolume);
    if (_ambientPlaying) {
      await stopAmbience();
      await startAmbience();
    }
  }

  Future<void> setReducedMotion(bool value) async {
    reducedMotion = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reducedMotionKey, value);
  }
}
