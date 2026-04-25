// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HOPE Rehabilitation';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String get appName => 'HOPE';

  @override
  String get appTagline => 'Smart Rehab System';

  @override
  String get getStarted => 'Get Started';

  @override
  String get chooseYourRole => 'Choose Your Role';

  @override
  String get roleIntro =>
      'Start your journey in physical therapy.\nChoose your role.';

  @override
  String get rolePatient => 'Patient';

  @override
  String get rolePatientDesc => 'Start a new rehabilitation session';

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get roleDoctorDesc => 'View session history and results';

  @override
  String get startSession => 'Start Session';

  @override
  String get readyToBegin => 'Ready to Begin?';

  @override
  String get sessionIntro =>
      'We will guide you through assessment and exercise with your HOPE glove.';

  @override
  String get startNewSession => 'Start New Session';

  @override
  String get linkGloveDevice => 'Link Glove Device';

  @override
  String get linkGloveToSession => 'Link Glove to Session';

  @override
  String get linkGloveDesc =>
      'Enter the device ID printed on your glove. The glove sends data over WiFi — no pairing needed.';

  @override
  String get deviceId => 'Device ID';

  @override
  String get linkDevice => 'Link Device';

  @override
  String get assessment => 'Assessment';

  @override
  String get waitingForAssessment => 'Waiting for Assessment';

  @override
  String get assessmentDesc =>
      'Put on the glove and perform the assessment motions. The glove sends sensor data over WiFi and the server will process your results automatically.';

  @override
  String get noGloveSimulate => 'No glove? Simulate it:';

  @override
  String get simulateGloveAssessment => 'Simulate Glove (Assessment)';

  @override
  String get simulateGloveExercise => 'Simulate Glove (Exercise)';

  @override
  String get assessmentResults => 'Assessment Results';

  @override
  String functionsPassed(int passed, int total) {
    return '$passed/$total functions passed';
  }

  @override
  String get continueToCheckin => 'Continue to Check-in';

  @override
  String get dailyCheckin => 'Daily Check-in';

  @override
  String get submit => 'Submit';

  @override
  String get skip => 'Skip';

  @override
  String get qSleep => 'How many hours did you sleep?';

  @override
  String get qTemperature => 'What is your body temperature?';

  @override
  String get qBloodSugar => 'What is your blood sugar level?';

  @override
  String get qBloodPressure => 'What is your blood pressure?';

  @override
  String get qHeadache => 'Do you have a headache?';

  @override
  String get qDizzy => 'Do you feel dizzy?';

  @override
  String get qFatigue => 'Do you feel fatigued or unusually tired?';

  @override
  String get qArmPain => 'Do you have any pain in your affected arm or hand?';

  @override
  String get qHandMovement => 'Are you able to move your hand today as usual?';

  @override
  String get qFalls =>
      'Have you experienced any falls or injuries since your last session?';

  @override
  String get hoursUnit => 'hours';

  @override
  String get celsiusUnit => '°C';

  @override
  String get mgdlUnit => 'mg/dL';

  @override
  String get systolic => 'Systolic';

  @override
  String get diastolic => 'Diastolic';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String questionProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get exercise => 'Exercise';

  @override
  String exerciseLabel(String name) {
    return 'Exercise: $name';
  }

  @override
  String get exerciseDesc =>
      'Perform the exercise while wearing the glove. When you\'re done, tap the \"Done\" button below.';

  @override
  String get waitingForExercise => 'Waiting for exercise data...';

  @override
  String get doneFetchResults => 'Done — Fetch Results';

  @override
  String get exerciseResults => 'Exercise Results';

  @override
  String get featureScores => 'Feature Scores';

  @override
  String get finishSession => 'Finish Session';

  @override
  String overallPercent(String percent) {
    return '$percent% overall';
  }

  @override
  String get sessionHistory => 'Session History';

  @override
  String get noSessionsFound => 'No sessions found';

  @override
  String assessSummary(int passed, int total) {
    return '$passed/$total PASS';
  }

  @override
  String get noAssessment => 'No assessment';

  @override
  String exerciseSummary(String percent) {
    return 'Exercise: $percent%';
  }

  @override
  String get sessionDetail => 'Session Detail';

  @override
  String get failedToLoadSession => 'Failed to load session';

  @override
  String get tabAssessment => 'Assessment';

  @override
  String get tabExercise => 'Exercise';

  @override
  String get tabInfo => 'Info';

  @override
  String get noAssessmentData => 'No assessment data';

  @override
  String get noExerciseData => 'No exercise data';

  @override
  String get questionnaire => 'Questionnaire';

  @override
  String get sessionVideo => 'Session Video';

  @override
  String get pass => 'PASS';

  @override
  String get fail => 'FAIL';

  @override
  String get statusCreated => 'created';

  @override
  String get statusQuestionnaireDone => 'questionnaire done';

  @override
  String get statusAssessed => 'assessed';

  @override
  String get statusExercised => 'exercised';

  @override
  String get statusCompleted => 'completed';

  @override
  String get statusInProgress => 'in progress';

  @override
  String get statusUnknown => 'unknown';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardWelcomePatient => 'Welcome back';

  @override
  String get dashboardWelcomeDoctor => 'Welcome, Doctor';

  @override
  String get dashboardSubtitle => 'Exercise scores over time';

  @override
  String get dashboardEmpty =>
      'No exercise data yet — finish a session to see your progress here.';

  @override
  String get dashboardEmptyForCategory => 'No data yet';

  @override
  String dashboardSession(int n) {
    return 'Session $n';
  }

  @override
  String get nextExercise => 'Next Exercise';

  @override
  String exerciseProgress(int current, int total, String name) {
    return 'Exercise $current of $total: $name';
  }

  @override
  String get redoAssessment => 'Redo Assessment';

  @override
  String get deleteSession => 'Delete Session';

  @override
  String get deleteSessionConfirmTitle => 'Delete this session?';

  @override
  String get deleteSessionConfirmBody =>
      'This will remove the session, its sensor data, and any uploaded video. This cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deletedConfirm => 'Session deleted';

  @override
  String get noInternet =>
      'You don\'t have internet. Check your connection and try again.';

  @override
  String get recordVideo => 'Record Video';

  @override
  String get videoRecording => 'Recording…';

  @override
  String get stopRecording => 'Stop';

  @override
  String get uploadingVideo => 'Uploading video…';

  @override
  String get videoUploaded => 'Video uploaded';

  @override
  String get videoUploadFailed => 'Video upload failed';

  @override
  String get labelSleepHours => 'Sleep (hours)';

  @override
  String get labelBodyTemperature => 'Body temperature (°C)';

  @override
  String get labelBloodSugar => 'Blood sugar (mg/dL)';

  @override
  String get labelBloodPressure => 'Blood pressure';

  @override
  String get labelHeadache => 'Headache';

  @override
  String get labelDizzy => 'Dizziness';

  @override
  String get labelFatigue => 'Fatigue';

  @override
  String get labelArmPain => 'Arm/hand pain';

  @override
  String get labelHandMovement => 'Hand movement OK';

  @override
  String get labelFallsInjuries => 'Falls/injuries since last session';

  @override
  String get questionnaireSkipped => 'Skipped';

  @override
  String get questionnaireNotFilled => 'Not filled';

  @override
  String get languageToggleTooltip => 'Change language';
}
