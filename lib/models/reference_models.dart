import 'package:appwrite/models.dart' as models;

/// Référentiel académique lu dans Appwrite : universités, facultés, filières
/// et salles. Quatre collections publiques (`read("any")`) ajoutées au schéma
/// le 2026-09-20 pour que **rien ne soit codé en dur** dans les clients — ni
/// « Université de Yaoundé I », ni « ICT4D », ni « L1 » : d'autres filières de
/// l'UY1 sont injectées en base et doivent apparaître sans mise à jour.

String _text(Map<String, dynamic> data, String key, [String fallback = '']) {
  final value = data[key];
  return value is String ? value : fallback;
}

bool _active(Map<String, dynamic> data) => data['active'] != false;

class University {
  final String id;
  final String code;
  final String name;
  final String shortName;
  final String city;
  final String country;
  final String website;
  final bool active;

  const University({
    required this.id,
    required this.code,
    required this.name,
    this.shortName = '',
    this.city = '',
    this.country = '',
    this.website = '',
    this.active = true,
  });

  factory University.fromDocument(models.Document doc) => University(
        id: doc.$id,
        code: _text(doc.data, 'code'),
        name: _text(doc.data, 'name'),
        shortName: _text(doc.data, 'shortName'),
        city: _text(doc.data, 'city'),
        country: _text(doc.data, 'country'),
        website: _text(doc.data, 'website'),
        active: _active(doc.data),
      );

  String get displayName => shortName.isEmpty ? name : '$name ($shortName)';
}

class Faculty {
  final String id;
  final String universityCode;
  final String code;
  final String name;
  final bool active;

  const Faculty({
    required this.id,
    required this.universityCode,
    required this.code,
    required this.name,
    this.active = true,
  });

  factory Faculty.fromDocument(models.Document doc) => Faculty(
        id: doc.$id,
        universityCode: _text(doc.data, 'universityCode'),
        code: _text(doc.data, 'code'),
        name: _text(doc.data, 'name'),
        active: _active(doc.data),
      );
}

class AcademicProgram {
  final String id;
  final String universityCode;
  final String facultyCode;

  /// Code court, celui que portent `users.program` et `academic_courses.program`.
  final String code;
  final String name;

  /// Niveaux ouverts, dans l'ordre déclaré (« L1,L2,L3 »).
  final List<String> levels;
  final String description;
  final bool active;

  const AcademicProgram({
    required this.id,
    required this.universityCode,
    required this.facultyCode,
    required this.code,
    required this.name,
    required this.levels,
    this.description = '',
    this.active = true,
  });

  factory AcademicProgram.fromDocument(models.Document doc) => AcademicProgram(
        id: doc.$id,
        universityCode: _text(doc.data, 'universityCode'),
        facultyCode: _text(doc.data, 'facultyCode'),
        code: _text(doc.data, 'code'),
        name: _text(doc.data, 'name'),
        levels: parseLevels(_text(doc.data, 'levels')),
        description: _text(doc.data, 'description'),
        active: _active(doc.data),
      );

  /// « L1, l2 ,L3 » → `['L1', 'L2', 'L3']`, sans doublon ni vide.
  static List<String> parseLevels(String raw) {
    final seen = <String>{};
    final levels = <String>[];
    for (final part in raw.split(RegExp(r'[,;\s]+'))) {
      final level = part.trim().toUpperCase();
      if (level.isEmpty || !seen.add(level)) continue;
      levels.add(level);
    }
    return levels;
  }

  String get displayName => name.isEmpty ? code : '$name ($code)';
}

class ClassroomRef {
  final String id;
  final String universityCode;
  final String facultyCode;
  final String code;
  final String name;
  final String kind;
  final int capacity;
  final String building;
  final bool active;

  const ClassroomRef({
    required this.id,
    required this.universityCode,
    this.facultyCode = '',
    required this.code,
    this.name = '',
    this.kind = 'SALLE',
    this.capacity = 0,
    this.building = '',
    this.active = true,
  });

  factory ClassroomRef.fromDocument(models.Document doc) => ClassroomRef(
        id: doc.$id,
        universityCode: _text(doc.data, 'universityCode'),
        facultyCode: _text(doc.data, 'facultyCode'),
        code: _text(doc.data, 'code'),
        name: _text(doc.data, 'name'),
        kind: _text(doc.data, 'kind', 'SALLE'),
        capacity: (doc.data['capacity'] is num)
            ? (doc.data['capacity'] as num).toInt()
            : 0,
        building: _text(doc.data, 'building'),
        active: _active(doc.data),
      );

  Map<String, dynamic> toPayload() => {
        'universityCode': universityCode,
        'facultyCode': facultyCode,
        'code': code,
        'name': name,
        'kind': kind,
        'capacity': capacity,
        'building': building,
        'active': active,
      };

  String get displayName => name.isEmpty ? code : '$code · $name';
}

/// Le référentiel complet, avec les filtres en cascade dont les formulaires
/// ont besoin (université → faculté → filière → niveau).
class AcademicReference {
  final List<University> universities;
  final List<Faculty> faculties;
  final List<AcademicProgram> programs;
  final List<ClassroomRef> classrooms;

  const AcademicReference({
    this.universities = const [],
    this.faculties = const [],
    this.programs = const [],
    this.classrooms = const [],
  });

  bool get isEmpty => universities.isEmpty && programs.isEmpty;

  List<Faculty> facultiesOf(String universityCode) => faculties
      .where((f) => f.active && f.universityCode == universityCode)
      .toList();

  List<AcademicProgram> programsOf(String universityCode,
          {String? facultyCode}) =>
      programs
          .where((p) =>
              p.active &&
              p.universityCode == universityCode &&
              (facultyCode == null ||
                  facultyCode.isEmpty ||
                  p.facultyCode == facultyCode))
          .toList();

  AcademicProgram? programByCode(String code) {
    for (final p in programs) {
      if (p.code == code) return p;
    }
    return null;
  }

  University? universityByCode(String code) {
    for (final u in universities) {
      if (u.code == code) return u;
    }
    return null;
  }

  /// Université dont le **nom** est celui enregistré sur un profil.
  University? universityByName(String name) {
    for (final u in universities) {
      if (u.name == name || u.shortName == name) return u;
    }
    return null;
  }

  /// Tous les codes de filière, triés.
  List<String> get programCodes =>
      (programs.where((p) => p.active).map((p) => p.code).toSet().toList()
        ..sort());

  /// Niveaux d'une filière, ou l'union de tous si la filière est inconnue.
  List<String> levelsOf(String? programCode) {
    final program = programCode == null ? null : programByCode(programCode);
    if (program != null && program.levels.isNotEmpty) return program.levels;
    final all = <String>{for (final p in programs) ...p.levels};
    final list = all.toList();
    list.sort();
    return list;
  }
}
