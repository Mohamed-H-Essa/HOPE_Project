// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'هوب لإعادة التأهيل';

  @override
  String get welcomeTo => 'مرحباً بك في';

  @override
  String get appName => 'HOPE';

  @override
  String get appTagline => 'نظام إعادة التأهيل الذكي';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get chooseYourRole => 'اختر دورك';

  @override
  String get roleIntro => 'ابدأ رحلتك في العلاج الطبيعي.\nاختر دورك.';

  @override
  String get rolePatient => 'مريض';

  @override
  String get rolePatientDesc => 'ابدأ جلسة إعادة تأهيل جديدة';

  @override
  String get roleDoctor => 'طبيب';

  @override
  String get roleDoctorDesc => 'عرض سجل الجلسات والنتائج';

  @override
  String get startSession => 'بدء الجلسة';

  @override
  String get readyToBegin => 'هل أنت مستعد للبدء؟';

  @override
  String get sessionIntro =>
      'سنرشدك خلال التقييم والتمارين باستخدام قفاز HOPE.';

  @override
  String get startNewSession => 'بدء جلسة جديدة';

  @override
  String get linkGloveDevice => 'ربط جهاز القفاز';

  @override
  String get linkGloveToSession => 'ربط القفاز بالجلسة';

  @override
  String get linkGloveDesc =>
      'أدخل معرّف الجهاز المطبوع على قفازك. يرسل القفاز البيانات عبر الواي فاي — لا حاجة للإقران.';

  @override
  String get deviceId => 'معرّف الجهاز';

  @override
  String get linkDevice => 'ربط الجهاز';

  @override
  String get assessment => 'التقييم';

  @override
  String get waitingForAssessment => 'في انتظار التقييم';

  @override
  String get assessmentDesc =>
      'ارتدِ القفاز وقم بحركات التقييم. يرسل القفاز بيانات الحساسات عبر الواي فاي وسيعالج الخادم نتائجك تلقائياً.';

  @override
  String get noGloveSimulate => 'لا يوجد قفاز؟ قم بمحاكاته:';

  @override
  String get simulateGloveAssessment => 'محاكاة القفاز (تقييم)';

  @override
  String get simulateGloveExercise => 'محاكاة القفاز (تمرين)';

  @override
  String get assessmentResults => 'نتائج التقييم';

  @override
  String functionsPassed(int passed, int total) {
    return 'اجتاز $passed من $total وظائف';
  }

  @override
  String get continueToCheckin => 'متابعة إلى التسجيل';

  @override
  String get dailyCheckin => 'التسجيل اليومي';

  @override
  String get submit => 'إرسال';

  @override
  String get skip => 'تخطي';

  @override
  String get qSleep => 'كم ساعة نمت؟';

  @override
  String get qTemperature => 'ما هي درجة حرارة جسمك؟';

  @override
  String get qBloodSugar => 'ما هو مستوى السكر في دمك؟';

  @override
  String get qBloodPressure => 'ما هو ضغط دمك؟';

  @override
  String get qHeadache => 'هل تعاني من صداع؟';

  @override
  String get qDizzy => 'هل تشعر بالدوار؟';

  @override
  String get qFatigue => 'هل تشعر بالتعب أو الإرهاق غير المعتاد؟';

  @override
  String get qArmPain => 'هل تعاني من ألم في ذراعك أو يدك المصابة؟';

  @override
  String get qHandMovement => 'هل يمكنك تحريك يدك اليوم كالمعتاد؟';

  @override
  String get qFalls => 'هل تعرضت لأي سقوط أو إصابات منذ جلستك الأخيرة؟';

  @override
  String get hoursUnit => 'ساعات';

  @override
  String get celsiusUnit => '°م';

  @override
  String get mgdlUnit => 'ملغ/دل';

  @override
  String get systolic => 'الانقباضي';

  @override
  String get diastolic => 'الانبساطي';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get next => 'التالي';

  @override
  String get back => 'السابق';

  @override
  String questionProgress(int current, int total) {
    return '$current من $total';
  }

  @override
  String get exercise => 'التمرين';

  @override
  String exerciseLabel(String name) {
    return 'التمرين: $name';
  }

  @override
  String get exerciseDesc =>
      'قم بأداء التمرين وأنت ترتدي القفاز. عند الانتهاء، اضغط زر \"تم\" في أسفل الشاشة.';

  @override
  String get waitingForExercise => 'في انتظار بيانات التمرين...';

  @override
  String get doneFetchResults => 'تم — جلب النتائج';

  @override
  String get exerciseResults => 'نتائج التمرين';

  @override
  String get featureScores => 'درجات الأداء';

  @override
  String get finishSession => 'إنهاء الجلسة';

  @override
  String overallPercent(String percent) {
    return '$percent% الإجمالي';
  }

  @override
  String get sessionHistory => 'سجل الجلسات';

  @override
  String get noSessionsFound => 'لا توجد جلسات';

  @override
  String assessSummary(int passed, int total) {
    return '$passed/$total نجح';
  }

  @override
  String get noAssessment => 'لا يوجد تقييم';

  @override
  String exerciseSummary(String percent) {
    return 'التمرين: $percent%';
  }

  @override
  String get sessionDetail => 'تفاصيل الجلسة';

  @override
  String get failedToLoadSession => 'فشل تحميل الجلسة';

  @override
  String get tabAssessment => 'التقييم';

  @override
  String get tabExercise => 'التمرين';

  @override
  String get tabInfo => 'معلومات';

  @override
  String get noAssessmentData => 'لا توجد بيانات تقييم';

  @override
  String get noExerciseData => 'لا توجد بيانات تمرين';

  @override
  String get questionnaire => 'الاستبيان';

  @override
  String get sessionVideo => 'فيديو الجلسة';

  @override
  String get pass => 'ناجح';

  @override
  String get fail => 'فشل';

  @override
  String get statusCreated => 'تم الإنشاء';

  @override
  String get statusQuestionnaireDone => 'تم الاستبيان';

  @override
  String get statusAssessed => 'تم التقييم';

  @override
  String get statusExercised => 'تم التمرين';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusInProgress => 'قيد التقدم';

  @override
  String get statusUnknown => 'غير معروف';

  @override
  String get redoAssessment => 'إعادة التقييم';

  @override
  String get deleteSession => 'حذف الجلسة';

  @override
  String get deleteSessionConfirmTitle => 'حذف هذه الجلسة؟';

  @override
  String get deleteSessionConfirmBody =>
      'سيؤدي هذا إلى إزالة الجلسة وبيانات الحساسات وأي فيديو تم رفعه. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get deletedConfirm => 'تم حذف الجلسة';

  @override
  String get noInternet =>
      'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم حاول مرة أخرى.';

  @override
  String get recordVideo => 'تسجيل فيديو';

  @override
  String get videoRecording => 'يسجل…';

  @override
  String get stopRecording => 'إيقاف';

  @override
  String get uploadingVideo => 'جارٍ رفع الفيديو…';

  @override
  String get videoUploaded => 'تم رفع الفيديو';

  @override
  String get videoUploadFailed => 'فشل رفع الفيديو';

  @override
  String get labelSleepHours => 'ساعات النوم';

  @override
  String get labelBodyTemperature => 'حرارة الجسم (°م)';

  @override
  String get labelBloodSugar => 'سكر الدم (ملغ/دل)';

  @override
  String get labelBloodPressure => 'ضغط الدم';

  @override
  String get labelHeadache => 'صداع';

  @override
  String get labelDizzy => 'دوار';

  @override
  String get labelFatigue => 'إرهاق';

  @override
  String get labelArmPain => 'ألم الذراع/اليد';

  @override
  String get labelHandMovement => 'حركة اليد طبيعية';

  @override
  String get labelFallsInjuries => 'سقوط/إصابات منذ الجلسة الأخيرة';

  @override
  String get questionnaireSkipped => 'تم التخطي';

  @override
  String get questionnaireNotFilled => 'لم يتم التعبئة';

  @override
  String get languageToggleTooltip => 'تغيير اللغة';
}
