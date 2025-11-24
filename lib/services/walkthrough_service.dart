import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class WalkthroughService {
  static const String _patientDashboardKey = 'walkthrough_patient_dashboard';
  static const String _myPatientsKey = 'walkthrough_my_patients';
  static const String _listenPageKey = 'walkthrough_listen';
  static const String _aiChatKey = 'walkthrough_ai_chat';
  static const String _voiceConversationKey = 'walkthrough_voice';
  static const String _newPatientKey = 'walkthrough_new_patient';

  Future<bool> hasSeenWalkthrough(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  Future<void> markWalkthroughSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  Future<void> resetAllWalkthroughs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_patientDashboardKey);
    await prefs.remove(_myPatientsKey);
    await prefs.remove(_listenPageKey);
    await prefs.remove(_aiChatKey);
    await prefs.remove(_voiceConversationKey);
    await prefs.remove(_newPatientKey);
  }

  static TutorialCoachMark createTutorial({
    required List<TargetFocus> targets,
    required VoidCallback onFinish,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        onFinish();
      },
      onSkip: () {
        onFinish();
        return true;
      },
    );
  }
}

class WalkthroughKeys {
  static const String patientDashboard = 'walkthrough_patient_dashboard';
  static const String myPatients = 'walkthrough_my_patients';
  static const String listen = 'walkthrough_listen';
  static const String aiChat = 'walkthrough_ai_chat';
  static const String voiceConversation = 'walkthrough_voice';
  static const String newPatient = 'walkthrough_new_patient';
}
