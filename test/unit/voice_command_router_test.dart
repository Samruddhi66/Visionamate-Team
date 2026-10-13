import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/core/speech/voice_command_router.dart';

void main() {
  group('VoiceCommandRouter Tests', () {
    test('Correctly maps describe surroundings intent in English and Marathi', () {
      final cmdEn = VoiceCommandRouter.parse('Describe my surroundings');
      expect(cmdEn.actionType, equals(VoiceActionType.describeSurroundings));

      final cmdFront = VoiceCommandRouter.parse('What is in front of me?');
      expect(cmdFront.actionType, equals(VoiceActionType.describeSurroundings));

      final cmdMr = VoiceCommandRouter.parse('आसपास काय आहे');
      expect(cmdMr.actionType, equals(VoiceActionType.describeSurroundings));
    });

    test('Correctly maps read text and OCR intent', () {
      final cmdSign = VoiceCommandRouter.parse('Read this sign');
      expect(cmdSign.actionType, equals(VoiceActionType.readText));

      final cmdDoc = VoiceCommandRouter.parse('Read document');
      expect(cmdDoc.actionType, equals(VoiceActionType.readText));

      final cmdMr = VoiceCommandRouter.parse('मजकूर वाचा');
      expect(cmdMr.actionType, equals(VoiceActionType.readText));
    });

    test('Correctly maps Indian currency identification intent', () {
      final cmdCurr = VoiceCommandRouter.parse('Identify this currency');
      expect(cmdCurr.actionType, equals(VoiceActionType.identifyCurrency));

      final cmdRupee = VoiceCommandRouter.parse('Check this rupee note');
      expect(cmdRupee.actionType, equals(VoiceActionType.identifyCurrency));

      final cmdMr = VoiceCommandRouter.parse('पैसे तपासा');
      expect(cmdMr.actionType, equals(VoiceActionType.identifyCurrency));
    });

    test('Correctly maps object detection and recognition intent', () {
      final cmdObj = VoiceCommandRouter.parse('Detect objects in front of me');
      expect(cmdObj.actionType, equals(VoiceActionType.identifyObject));

      final cmdIdentify = VoiceCommandRouter.parse('Identify object');
      expect(cmdIdentify.actionType, equals(VoiceActionType.identifyObject));

      final cmdFind = VoiceCommandRouter.parse('Find objects');
      expect(cmdFind.actionType, equals(VoiceActionType.identifyObject));

      final cmdWhat = VoiceCommandRouter.parse('What is this');
      expect(cmdWhat.actionType, equals(VoiceActionType.identifyObject));
    });

    test('Correctly maps navigation with destination argument extraction', () {
      final cmdNav = VoiceCommandRouter.parse('Navigate to COEP College');
      expect(cmdNav.actionType, equals(VoiceActionType.navigateToPlace));
      expect(cmdNav.argument, equals('COEP College'));

      final cmdTake = VoiceCommandRouter.parse('Take me to Shivajinagar Station');
      expect(cmdTake.actionType, equals(VoiceActionType.navigateToPlace));
      expect(cmdTake.argument, equals('Shivajinagar Station'));
    });

    test('Correctly flags emergency SOS with high priority and confirmation', () {
      final cmdSos = VoiceCommandRouter.parse('Emergency! Help me!');
      expect(cmdSos.actionType, equals(VoiceActionType.emergencySos));
      expect(cmdSos.requiresConfirmation, isTrue);

      final cmdMr = VoiceCommandRouter.parse('मदत करा');
      expect(cmdMr.actionType, equals(VoiceActionType.emergencySos));
      expect(cmdMr.requiresConfirmation, isTrue);
    });

    test('Handles low confidence speech safely with confirmation prompt', () {
      final lowConfCmd = VoiceCommandRouter.parse('muffled audio', confidence: 0.35);
      expect(lowConfCmd.actionType, equals(VoiceActionType.unknown));
      expect(lowConfCmd.requiresConfirmation, isTrue);
      expect(lowConfCmd.confirmationPrompt, contains('speech was unclear'));
    });

    test('Handles stop and repeat instructions', () {
      final cmdStop = VoiceCommandRouter.parse('Stop speaking');
      expect(cmdStop.actionType, equals(VoiceActionType.stopSpeaking));

      final cmdRepeat = VoiceCommandRouter.parse('Repeat last instruction');
      expect(cmdRepeat.actionType, equals(VoiceActionType.repeatLast));
    });
  });
}
