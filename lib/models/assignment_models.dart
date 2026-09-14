import 'dart:convert';

import 'package:appwrite/appwrite.dart';
// Les modèles de réponse ne sont pas ré-exportés par `appwrite.dart`.
import 'package:appwrite/models.dart' as models;

/// Nature d'un devoir publié par un enseignant.
enum AssignmentType {
  /// Questionnaire à choix, décrit par un JSON (`quizJson`).
  quiz,

  /// Énoncé au format PDF, à rendre.
  pdf,

  /// Travaux dirigés, à rendre.
  td;

  /// Libellé affiché dans l'interface.
  String get label => switch (this) {
        AssignmentType.quiz => 'Quiz',
        AssignmentType.pdf => 'PDF',
        AssignmentType.td => 'TD',
      };

  /// Reconstruit le type depuis la valeur stockée en base.
  ///
  /// Une valeur inconnue retombe sur [AssignmentType.td] plutôt que de lever :
  /// une ligne écrite par une version plus récente ne doit pas rendre tout
  /// l'écran illisible.
  static AssignmentType parse(String? raw) => switch (raw?.toUpperCase()) {
        'QUIZ' => AssignmentType.quiz,
        'PDF' => AssignmentType.pdf,
        _ => AssignmentType.td,
      };
}

/// État de publication d'un devoir.
enum AssignmentStatus {
  draft,
  published,
  closed;

  String get value => name.toUpperCase();

  static AssignmentStatus parse(String? raw) => switch (raw?.toUpperCase()) {
        'PUBLISHED' => AssignmentStatus.published,
        'CLOSED' => AssignmentStatus.closed,
        _ => AssignmentStatus.draft,
      };
}

/// État d'un rendu d'élève.
enum SubmissionStatus {
  submitted,
  late,
  graded;

  String get value => name.toUpperCase();

  String get label => switch (this) {
        SubmissionStatus.submitted => 'Rendu',
        SubmissionStatus.late => 'En retard',
        SubmissionStatus.graded => 'Corrigé',
      };

  static SubmissionStatus parse(String? raw) => switch (raw?.toUpperCase()) {
        'LATE' => SubmissionStatus.late,
        'GRADED' => SubmissionStatus.graded,
        _ => SubmissionStatus.submitted,
      };
}

/// Un devoir : l'énoncé publié par l'enseignant, commun à toute une promotion.
///
/// Le modèle est volontairement distinct du rendu ([Submission]) : l'énoncé
/// existe une fois, les rendus sont nombreux. La version précédente du code
/// dupliquait l'énoncé par élève dans `academic_assignments`, ce qui rendait
/// impossible de savoir qui avait rendu.
class Assignment {
  final String id;
  final String title;
  final String? description;
  final String courseId;
  final String courseCode;
  final String teacherId;
  final String? teacherName;
  final AssignmentType type;
  final AssignmentStatus status;
  final DateTime dueDate;
  final DateTime? publishedAt;
  final double maxScore;
  final bool allowLate;

  /// Définition du quiz, telle que saisie par l'enseignant.
  final String? quizJson;

  /// Fichier de l'énoncé (PDF ou TD) dans le bucket `uniflow_assets`.
  final String? fileId;
  final String? fileName;

  /// Public visé : `{"filieres": [...], "niveaux": [...]}`.
  ///
  /// Vide signifie « tout le monde » — c'est le cas par défaut à la création,
  /// et cela évite qu'un devoir mal renseigné ne soit invisible pour tous.
  final String? audience;

  const Assignment({
    required this.id,
    required this.title,
    this.description,
    required this.courseId,
    required this.courseCode,
    required this.teacherId,
    this.teacherName,
    required this.type,
    required this.status,
    required this.dueDate,
    this.publishedAt,
    this.maxScore = 20,
    this.allowLate = false,
    this.quizJson,
    this.fileId,
    this.fileName,
    this.audience,
  });

  /// Le délai est dépassé.
  bool get isPastDue => DateTime.now().isAfter(dueDate);

  /// Un rendu est encore accepté.
  bool get acceptsSubmission => !isPastDue || allowLate;

  /// L'énoncé est un fichier à télécharger.
  bool get hasFile => fileId != null && fileId!.isNotEmpty;

  /// Le devoir a un corrigé automatique possible.
  bool get isAutoGraded => type == AssignmentType.quiz && quiz != null;

  /// Quiz décodé, ou `null` si le JSON est absent ou illisible.
  ///
  /// L'échec de décodage est silencieux ici et signalé à l'écran : jeter une
  /// exception rendrait toute la liste des devoirs inutilisable à cause d'un
  /// seul énoncé mal formé.
  QuizDefinition? get quiz {
    final raw = quizJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return QuizDefinition.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  factory Assignment.fromDocument(models.Document doc) {
    final d = doc.data;
    return Assignment(
      id: doc.$id,
      title: (d['title'] ?? '').toString(),
      description: _nullIfEmpty(d['description']),
      courseId: (d['courseId'] ?? '').toString(),
      courseCode: (d['courseCode'] ?? '').toString(),
      teacherId: (d['teacherId'] ?? '').toString(),
      teacherName: _nullIfEmpty(d['teacherName']),
      type: AssignmentType.parse(d['type']?.toString()),
      status: AssignmentStatus.parse(d['status']?.toString()),
      dueDate: _parseDate(d['dueDate']) ?? DateTime.now(),
      publishedAt: _parseDate(d['publishedAt']),
      maxScore: _parseDouble(d['maxScore'], fallback: 20),
      allowLate: d['allowLate'] == true,
      quizJson: _nullIfEmpty(d['quizJson']),
      fileId: _nullIfEmpty(d['fileId']),
      fileName: _nullIfEmpty(d['fileName']),
      audience: _nullIfEmpty(d['audience']),
    );
  }

  /// Charge utile envoyée à Appwrite.
  Map<String, dynamic> toPayload() => {
        'title': title,
        'description': description,
        'courseId': courseId,
        'courseCode': courseCode,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'type': type.name.toUpperCase(),
        'status': status.value,
        'dueDate': dueDate.toUtc().toIso8601String(),
        'publishedAt': (publishedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'maxScore': maxScore,
        'allowLate': allowLate,
        'quizJson': quizJson,
        'fileId': fileId,
        'fileName': fileName,
        'audience': audience,
      };

  /// Le devoir vise-t-il un élève donné ?
  ///
  /// Une audience vide ou illisible vaut « tout le monde » : mieux vaut un
  /// devoir visible par trop de monde qu'un devoir que personne ne reçoit.
  bool targets({String? filiere, String? niveau}) {
    final raw = audience;
    if (raw == null || raw.trim().isEmpty) return true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return true;
      final filieres = _stringList(decoded['filieres']);
      final niveaux = _stringList(decoded['niveaux']);
      if (filieres.isEmpty && niveaux.isEmpty) return true;
      final filiereOk = filieres.isEmpty || (filiere != null && filieres.contains(filiere));
      final niveauOk = niveaux.isEmpty || (niveau != null && niveaux.contains(niveau));
      return filiereOk && niveauOk;
    } catch (_) {
      return true;
    }
  }
}

/// Un rendu d'élève pour un devoir.
class Submission {
  final String id;
  final String assignmentId;
  final String studentId;
  final String? studentName;
  final DateTime submittedAt;

  /// Réponses au quiz, au format `{"q1": 2, "q2": [0,2], "q3": "texte"}`.
  final String? answersJson;
  final String? fileId;
  final String? fileName;
  final double? score;
  final String? feedback;
  final SubmissionStatus status;
  final DateTime? gradedAt;

  const Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.studentName,
    required this.submittedAt,
    this.answersJson,
    this.fileId,
    this.fileName,
    this.score,
    this.feedback,
    required this.status,
    this.gradedAt,
  });

  bool get hasFile => fileId != null && fileId!.isNotEmpty;

  /// Réponses décodées, indexées par identifiant de question.
  Map<String, dynamic> get answers {
    final raw = answersJson;
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const {};
    }
  }

  factory Submission.fromDocument(models.Document doc) {
    final d = doc.data;
    return Submission(
      id: doc.$id,
      assignmentId: (d['assignmentId'] ?? '').toString(),
      studentId: (d['studentId'] ?? '').toString(),
      studentName: _nullIfEmpty(d['studentName']),
      submittedAt: _parseDate(d['submittedAt']) ?? DateTime.now(),
      answersJson: _nullIfEmpty(d['answersJson']),
      fileId: _nullIfEmpty(d['fileId']),
      fileName: _nullIfEmpty(d['fileName']),
      score: d['score'] == null ? null : _parseDouble(d['score'], fallback: 0),
      feedback: _nullIfEmpty(d['feedback']),
      status: SubmissionStatus.parse(d['status']?.toString()),
      gradedAt: _parseDate(d['gradedAt']),
    );
  }

  Map<String, dynamic> toPayload() => {
        'assignmentId': assignmentId,
        'studentId': studentId,
        'studentName': studentName,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        'answersJson': answersJson,
        'fileId': fileId,
        'fileName': fileName,
        'score': score,
        'feedback': feedback,
        'status': status.value,
        'gradedAt': gradedAt?.toUtc().toIso8601String(),
      };
}

/// Type d'une question de quiz.
enum QuestionType {
  /// Une seule bonne réponse : `correct` contient un unique indice.
  single,

  /// Plusieurs bonnes réponses.
  multiple,

  /// Réponse libre, comparée au corrigé sans tenir compte de la casse.
  text;

  static QuestionType parse(String? raw) => switch (raw?.toLowerCase()) {
        'multiple' => QuestionType.multiple,
        'text' => QuestionType.text,
        _ => QuestionType.single,
      };
}

/// Une question de quiz.
class QuizQuestion {
  final String id;
  final QuestionType type;
  final String prompt;
  final List<String> choices;

  /// Indices des bonnes réponses pour [QuestionType.single] et
  /// [QuestionType.multiple].
  final List<int> correct;

  /// Réponse attendue pour [QuestionType.text].
  final String? expected;

  final double points;

  /// Affichée après correction pour expliquer la réponse.
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.choices = const [],
    this.correct = const [],
    this.expected,
    this.points = 1,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json, int index) {
    final type = QuestionType.parse(json['type']?.toString());
    return QuizQuestion(
      // Un identifiant absent est reconstruit depuis la position : deux
      // questions sans identifiant ne doivent pas se recouvrir dans les
      // réponses enregistrées.
      id: (json['id'] ?? 'q${index + 1}').toString(),
      type: type,
      prompt: (json['prompt'] ?? json['question'] ?? '').toString(),
      choices: _stringList(json['choices']),
      correct: _intList(json['correct'] ?? json['answers'] ?? json['answer']),
      expected: json['expected']?.toString() ?? json['answer']?.toString(),
      points: _parseDouble(json['points'], fallback: 1),
      explanation: json['explanation']?.toString(),
    );
  }
}

/// Un quiz complet, décodé depuis `quizJson`.
class QuizDefinition {
  final String? title;
  final int? durationMinutes;
  final List<QuizQuestion> questions;

  const QuizDefinition({
    this.title,
    this.durationMinutes,
    required this.questions,
  });

  /// Somme des points de toutes les questions.
  double get totalPoints =>
      questions.fold<double>(0, (sum, q) => sum + q.points);

  factory QuizDefinition.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'];
    final questions = <QuizQuestion>[];
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map) {
          questions.add(QuizQuestion.fromJson(Map<String, dynamic>.from(item), i));
        }
      }
    }
    return QuizDefinition(
      title: json['title']?.toString(),
      durationMinutes: int.tryParse('${json['durationMinutes'] ?? json['duration'] ?? ''}'),
      questions: questions,
    );
  }
}

/// Résultat de la correction automatique d'un quiz.
class QuizResult {
  final double earned;
  final double total;
  final List<QuestionOutcome> outcomes;

  const QuizResult({
    required this.earned,
    required this.total,
    required this.outcomes,
  });

  /// Note ramenée sur le barème du devoir.
  double scaledTo(double maxScore) => total <= 0 ? 0 : earned / total * maxScore;

  /// Nombre de questions justes.
  int get correctCount => outcomes.where((o) => o.isCorrect).length;
}

/// Correction d'une question.
class QuestionOutcome {
  final QuizQuestion question;
  final bool isCorrect;
  final double earned;

  const QuestionOutcome({
    required this.question,
    required this.isCorrect,
    required this.earned,
  });
}

/// Moteur de correction d'un quiz.
///
/// Fonction pure : elle ne touche ni au réseau ni au stockage, ce qui la rend
/// vérifiable par des tests unitaires — la note d'un élève ne doit pas dépendre
/// d'une requête Appwrite pour être calculée.
class QuizGrader {
  QuizGrader._();

  /// Corrige [quiz] à partir des réponses `{idQuestion: réponse}`.
  static QuizResult grade(QuizDefinition quiz, Map<String, dynamic> answers) {
    final outcomes = <QuestionOutcome>[];
    var earned = 0.0;

    for (final question in quiz.questions) {
      final given = answers[question.id];
      final correct = isCorrect(question, given);
      final points = correct ? question.points : 0.0;
      earned += points;
      outcomes.add(
        QuestionOutcome(question: question, isCorrect: correct, earned: points),
      );
    }

    return QuizResult(earned: earned, total: quiz.totalPoints, outcomes: outcomes);
  }

  /// Une question est-elle juste ?
  static bool isCorrect(QuizQuestion question, dynamic given) {
    switch (question.type) {
      case QuestionType.single:
        final expected = question.correct.isEmpty ? null : question.correct.first;
        if (expected == null) return false;
        return _asInt(given) == expected;

      case QuestionType.multiple:
        if (question.correct.isEmpty) return false;
        final givenSet = _intList(given).toSet();
        final expectedSet = question.correct.toSet();
        // Ensembles égaux : cocher toutes les bonnes réponses et rien d'autre.
        return givenSet.length == expectedSet.length &&
            givenSet.containsAll(expectedSet);

      case QuestionType.text:
        final expected = (question.expected ?? '').trim();
        if (expected.isEmpty) return false;
        // Comparaison insensible à la casse et aux espaces surnuméraires : une
        // majuscule oubliée ne doit pas coûter la totalité des points.
        return _normalize(given?.toString() ?? '') == _normalize(expected);
    }
  }

  /// Réduit une réponse libre à sa forme comparable.
  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

// ─── Utilitaires de conversion ──────────────────────────────────────────────

String? _nullIfEmpty(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}

double _parseDouble(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

List<int> _intList(dynamic value) {
  if (value is List) {
    return value.map((e) {
      if (e is int) return e;
      if (e is double) return e.toInt();
      return int.tryParse(e.toString()) ?? -1;
    }).where((e) => e >= 0).toList();
  }
  if (value is int) return [value];
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    return parsed == null ? const [] : [parsed];
  }
  return const [];
}
