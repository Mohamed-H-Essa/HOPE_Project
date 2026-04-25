/// Per-exercise YouTube tutorial URLs. The exercise-waiting screen renders
/// the video for whichever exercise the patient is currently on.
///
/// **TO SWAP A VIDEO:** replace the right-hand URL for the corresponding key.
/// Keys must match the assessment category names produced by
/// `backend/lambdas/hope_ingest/assess_logic.py` ("Reach", "Grasp",
/// "Manipulation", "Release"). All four currently point at the same
/// placeholder until the real videos are ready.
const Map<String, String> exerciseVideoUrls = {
  'Reach': 'https://www.youtube.com/watch?v=7N8IDv8viZk',
  'Grasp': 'https://www.youtube.com/watch?v=7N8IDv8viZk',
  'Manipulation': 'https://www.youtube.com/watch?v=7N8IDv8viZk',
  'Release': 'https://www.youtube.com/watch?v=7N8IDv8viZk',
};

const String _fallbackVideoUrl = 'https://www.youtube.com/watch?v=7N8IDv8viZk';

String videoUrlFor(String exerciseName) =>
    exerciseVideoUrls[exerciseName] ?? _fallbackVideoUrl;
