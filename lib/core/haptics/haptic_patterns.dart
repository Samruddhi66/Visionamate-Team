/// Distinct named tactile feedback patterns for VisionMate 2.0
enum HapticPattern {
  /// Quick single light tick for button presses & focus
  lightTap,

  /// General button tap feedback
  buttonTap,

  /// Selection click feedback
  selectionClick,

  /// Two quick sharp pulses for action success
  actionSuccess,

  /// Heavy warning buzz for invalid actions or errors
  actionError,

  /// Warning impending pulse
  warningImpending,

  /// Ascending feedback when speech recognition starts
  listeningStarted,

  /// Subtle pulse when AI inference begins
  processingStarted,

  /// Two spaced pulses to indicate a left turn
  navigationTurnLeft,

  /// Three quick pulses to indicate a right turn
  navigationTurnRight,

  /// Long continuous pleasant vibration upon arrival at destination
  destinationArrival,

  /// Urgent pulsating pattern for nearby obstacles/hazards
  hazardDetected,

  /// Strong rhythmic pulses signaling active emergency mode
  emergencyStatus,

  /// Gentle confirmation when API key is verified
  apiKeyVerified,

  /// Subtle double-tap for navigation starting
  navigationStarted,

  /// Single rising pulse for "scanning" or "analyzing"
  scanningStarted,

  /// Gentle descending pattern when analysis completes
  analysisComplete,

  /// Soft pulse when voice recognition confirms a command
  commandRecognized,

  /// Gentle pulse for low battery or network warnings
  systemNotice,
}

extension HapticPatternDetails on HapticPattern {
  /// Accessible spoken alternative for users who cannot feel vibration
  /// or on devices without vibration motors.
  String get spokenAlternative {
    switch (this) {
      case HapticPattern.lightTap:
      case HapticPattern.buttonTap:
      case HapticPattern.selectionClick:
        return 'Tapped';
      case HapticPattern.actionSuccess:
        return 'Success';
      case HapticPattern.actionError:
        return 'Action failed';
      case HapticPattern.warningImpending:
        return 'Warning';
      case HapticPattern.listeningStarted:
        return 'Listening started';
      case HapticPattern.processingStarted:
        return 'Processing';
      case HapticPattern.navigationTurnLeft:
        return 'Turn left';
      case HapticPattern.navigationTurnRight:
        return 'Turn right';
      case HapticPattern.destinationArrival:
        return 'You have arrived at your destination';
      case HapticPattern.hazardDetected:
        return 'Hazard alert! Possible obstacle ahead';
      case HapticPattern.emergencyStatus:
        return 'Emergency alert active';
      case HapticPattern.apiKeyVerified:
        return 'API key verified successfully';
      case HapticPattern.navigationStarted:
        return 'Navigation started';
      case HapticPattern.scanningStarted:
        return 'Scanning started';
      case HapticPattern.analysisComplete:
        return 'Analysis complete';
      case HapticPattern.commandRecognized:
        return 'Command recognized';
      case HapticPattern.systemNotice:
        return 'Notice';
    }
  }

  /// Millisecond vibration patterns for devices supporting custom waveforms
  /// Format: [wait, vibrate, wait, vibrate...]
  List<int> get vibrationDurationsMs {
    switch (this) {
      case HapticPattern.lightTap:
      case HapticPattern.buttonTap:
      case HapticPattern.selectionClick:
        return [0, 40];
      case HapticPattern.actionSuccess:
        return [0, 60, 60, 80];
      case HapticPattern.actionError:
        return [0, 200, 100, 250];
      case HapticPattern.warningImpending:
        return [0, 120, 60, 120];
      case HapticPattern.listeningStarted:
        return [0, 50, 40, 70];
      case HapticPattern.processingStarted:
        return [0, 50];
      case HapticPattern.navigationTurnLeft:
        return [0, 150, 120, 150];
      case HapticPattern.navigationTurnRight:
        return [0, 80, 80, 80, 80, 80];
      case HapticPattern.destinationArrival:
        return [0, 400, 150, 500];
      case HapticPattern.hazardDetected:
        return [0, 250, 80, 250, 80, 300];
      case HapticPattern.emergencyStatus:
        return [0, 500, 200, 500, 200, 500];
      case HapticPattern.apiKeyVerified:
        return [0, 80, 100, 120];
      case HapticPattern.navigationStarted:
        return [0, 100, 80, 100];
      case HapticPattern.scanningStarted:
        return [0, 60, 60, 60];
      case HapticPattern.analysisComplete:
        return [0, 80, 60, 60];
      case HapticPattern.commandRecognized:
        return [0, 50, 50, 50];
      case HapticPattern.systemNotice:
        return [0, 100];
    }
  }
}
