// Le schéma du 2026-09-20 ajoute à `academic_schedules` la filière, le niveau,
// l'intitulé et l'enseignant : le modèle doit les lire quand ils sont là et
// rester muet (chaîne vide) sur les anciens documents qui ne les portent pas.

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow/models/appwrite_models.dart';

void main() {
  test('séance enrichie : tous les champs du nouveau schéma sont lus', () {
    final s = AcademicSchedule.fromData('s1', {
      'courseId': 'c1',
      'courseCode': 'PHY301',
      'dayOfWeek': 'Lundi',
      'startTime': '07:30',
      'endTime': '10:30',
      'classroom': 'A250',
      'type': 'TD Gr1',
      'university': 'Université de Yaoundé I',
      'program': 'PHY',
      'level': 'L3',
      'courseName': 'Mécanique quantique',
      'teacherName': 'Dr Nkoumou',
      'group': 'Gr1',
      'semester': 'S1',
      'academicYear': '2026-2027',
    });
    expect(s.program, 'PHY');
    expect(s.level, 'L3');
    expect(s.courseName, 'Mécanique quantique');
    expect(s.teacherName, 'Dr Nkoumou');
    expect(s.group, 'Gr1');
    expect(s.semester, 'S1');
    expect(s.academicYear, '2026-2027');
    expect(s.type, 'TD Gr1');
  });

  test('ancien document : champs absents ou d\'un autre type → chaînes vides',
      () {
    final s = AcademicSchedule.fromData('s2', {
      'courseId': 'c2',
      'dayOfWeek': 'Mardi',
      'startTime': '08:00',
      'endTime': '10:00',
      'level': 3, // type inattendu : ne doit pas planter
    });
    expect(s.program, '');
    expect(s.level, '');
    expect(s.courseName, '');
    expect(s.teacherName, '');
    expect(s.type, isNull);
    expect(s.classroom, '');
  });
}
