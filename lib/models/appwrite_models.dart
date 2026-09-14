import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

/// "L1" -> "Licence 1" : la base stocke le code, l'interface affiche le nom.
String directoryLevelLabel(String level) {
  const labels = {
    'L1': 'Licence 1',
    'L2': 'Licence 2',
    'L3': 'Licence 3',
    'M1': 'Master 1',
    'M2': 'Master 2',
  };
  return labels[level] ?? level;
}

/// Statut d'annuaire (`ACTIVE`, `SUSPENDED`…) rendu lisible.
String directoryStatusLabel(String? status) {
  switch ((status ?? '').toUpperCase()) {
    case 'ACTIVE':
      return 'Actif';
    case 'SUSPENDED':
      return 'Suspendu';
    default:
      return 'En attente';
  }
}

/// Couleur associée au statut, alignée sur la charte du desktop.
Color directoryStatusColor(String? status) {
  switch ((status ?? '').toUpperCase()) {
    case 'ACTIVE':
      return const Color(0xFF34C77B);
    case 'SUSPENDED':
      return const Color(0xFFE85C5C);
    default:
      return const Color(0xFFF5A623);
  }
}

class AcademicCourse {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String university;
  final String program;
  final String level;
  final String? teacherId;
  final String? teacherName;
  final int? credits;
  final int? hours;
  final String? classroom;
  final String? type;

  AcademicCourse({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.university,
    required this.program,
    required this.level,
    this.teacherId,
    this.teacherName,
    this.credits,
    this.hours,
    this.classroom,
    this.type,
  });

  factory AcademicCourse.fromDocument(models.Document doc) {
    return AcademicCourse(
      id: doc.$id,
      code: doc.data['code'] ?? '',
      name: doc.data['name'] ?? '',
      description: doc.data['description'],
      university: doc.data['university'] ?? '',
      program: doc.data['program'] ?? '',
      level: doc.data['level'] ?? 'L1',
      teacherId: doc.data['teacherId'],
      teacherName: doc.data['teacherName'],
      credits: doc.data['credits'],
      hours: doc.data['hours'],
      classroom: doc.data['classroom'],
      type: doc.data['type'],
    );
  }
}

class AcademicSchedule {
  final String id;
  final String courseId;
  final String courseCode;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String classroom;
  final String? type;

  AcademicSchedule({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.classroom,
    this.type,
  });

  factory AcademicSchedule.fromDocument(models.Document doc) {
    return AcademicSchedule(
      id: doc.$id,
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      dayOfWeek: doc.data['dayOfWeek'] ?? '',
      startTime: doc.data['startTime'] ?? '',
      endTime: doc.data['endTime'] ?? '',
      classroom: doc.data['classroom'] ?? '',
      type: doc.data['type'],
    );
  }
}

class AcademicDirectoryEntry {
  final String id;
  final String userId;
  final String name;
  final String role;
  final String university;
  final String program;
  final String level;
  final String? matricule;
  final String? status;

  /// Ces trois champs vivent dans la collection `users`, pas dans
  /// `academic_directory` : le dépôt les joint avant de renvoyer l'entrée.
  final String? email;
  final String? username;
  final String? avatarFileId;

  AcademicDirectoryEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.university,
    required this.program,
    required this.level,
    this.matricule,
    this.status,
    this.email,
    this.username,
    this.avatarFileId,
  });

  factory AcademicDirectoryEntry.fromDocument(models.Document doc) {
    return AcademicDirectoryEntry(
      id: doc.$id,
      userId: doc.data['userId'] ?? '',
      name: doc.data['name'] ?? '',
      role: doc.data['role'] ?? 'STUDENT',
      university: doc.data['university'] ?? '',
      program: doc.data['program'] ?? '',
      level: doc.data['level'] ?? 'L1',
      matricule: doc.data['matricule'],
      status: doc.data['status'],
    );
  }

  /// Complète l'entrée avec les données de profil de `users`.
  AcademicDirectoryEntry withProfile({
    String? email,
    String? username,
    String? avatarFileId,
  }) {
    return AcademicDirectoryEntry(
      id: id,
      userId: userId,
      name: name,
      role: role,
      university: university,
      program: program,
      level: level,
      matricule: matricule,
      status: status,
      email: email,
      username: username,
      avatarFileId: avatarFileId,
    );
  }
}

class AcademicGrade {
  final String id;
  final String studentId;
  final String courseId;
  final String courseCode;
  final String evaluationTitle;
  final String? type;
  final double score;
  final double maxScore;
  final double coefficient;

  AcademicGrade({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseCode,
    required this.evaluationTitle,
    this.type,
    required this.score,
    required this.maxScore,
    required this.coefficient,
  });

  factory AcademicGrade.fromDocument(models.Document doc) {
    return AcademicGrade(
      id: doc.$id,
      studentId: doc.data['studentId'] ?? '',
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      evaluationTitle: doc.data['evaluationTitle'] ?? '',
      type: doc.data['type'],
      score: (doc.data['score'] ?? 0).toDouble(),
      maxScore: (doc.data['maxScore'] ?? 20).toDouble(),
      coefficient: (doc.data['coefficient'] ?? 1).toDouble(),
    );
  }
}

class AcademicAssignment {
  final String id;
  final String courseId;
  final String courseCode;
  final String studentId;
  final String title;
  final String? description;
  final String dueDate;
  final String? status;
  final String? grade;
  final String? feedback;
  final String? submittedAt;

  AcademicAssignment({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.studentId,
    required this.title,
    this.description,
    required this.dueDate,
    this.status,
    this.grade,
    this.feedback,
    this.submittedAt,
  });

  factory AcademicAssignment.fromDocument(models.Document doc) {
    return AcademicAssignment(
      id: doc.$id,
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      studentId: doc.data['studentId'] ?? '',
      title: doc.data['title'] ?? '',
      description: doc.data['description'],
      dueDate: doc.data['dueDate'] ?? '',
      status: doc.data['status'],
      grade: doc.data['grade'],
      feedback: doc.data['feedback'],
      submittedAt: doc.data['submittedAt'],
    );
  }
}

class AcademicLibraryEntry {
  final String id;
  final String title;
  final String courseId;
  final String course;
  final String type;
  final String category;
  final String? size;
  final String? description;
  final String? fileId;
  final String publishedAt;

  AcademicLibraryEntry({
    required this.id,
    required this.title,
    required this.courseId,
    required this.course,
    required this.type,
    required this.category,
    this.size,
    this.description,
    this.fileId,
    required this.publishedAt,
  });

  factory AcademicLibraryEntry.fromDocument(models.Document doc) {
    return AcademicLibraryEntry(
      id: doc.$id,
      title: doc.data['title'] ?? '',
      courseId: doc.data['courseId'] ?? '',
      course: doc.data['course'] ?? '',
      type: doc.data['type'] ?? '',
      category: doc.data['category'] ?? '',
      size: doc.data['size'],
      description: doc.data['description'],
      fileId: doc.data['fileId'],
      publishedAt: doc.data['publishedAt'] ?? '',
    );
  }
}

class PersonalSubject {
  final String id;
  final String ownerId;
  final String name;
  final String? code;
  final String? instructor;
  final int? credits;
  final String? colorHex;
  final String? classroom;
  final String? description;

  PersonalSubject({
    required this.id,
    required this.ownerId,
    required this.name,
    this.code,
    this.instructor,
    this.credits,
    this.colorHex,
    this.classroom,
    this.description,
  });

  factory PersonalSubject.fromDocument(models.Document doc) {
    return PersonalSubject(
      id: doc.$id,
      ownerId: doc.data['ownerId'] ?? '',
      name: doc.data['name'] ?? doc.data['title'] ?? '',
      code: doc.data['code'],
      instructor: doc.data['instructor'],
      credits: doc.data['credits'],
      colorHex: doc.data['colorHex'],
      classroom: doc.data['classroom'],
      description: doc.data['description'],
    );
  }
}

class PersonalTask {
  final String id;
  final String ownerId;
  final String title;
  final String? courseId;
  final String? dueDate;
  final String? description;
  final int? priority;
  final String? status;

  PersonalTask({
    required this.id,
    required this.ownerId,
    required this.title,
    this.courseId,
    this.dueDate,
    this.description,
    this.priority,
    this.status,
  });

  factory PersonalTask.fromDocument(models.Document doc) {
    return PersonalTask(
      id: doc.$id,
      ownerId: doc.data['ownerId'] ?? '',
      title: doc.data['title'] ?? '',
      courseId: doc.data['courseId'],
      dueDate: doc.data['dueDate'],
      description: doc.data['description'],
      priority: doc.data['priority'],
      status: doc.data['status'],
    );
  }
}

class UniFlowUser {
  final String id;
  final String email;
  final String name;
  final String accountType; // 'UNIVERSITY' | 'PERSONAL'
  final String role; // 'STUDENT' | 'DELEGATE' | 'TEACHER' | 'ADMIN'
  final String? university;
  final String? program;
  final String? level;
  final String? country;

  /// Pseudo unique : c'est le référent de la messagerie.
  final String? username;

  /// Fichier de la photo de profil dans le bucket Appwrite `uniflow_avatars`.
  final String? avatarFileId;

  UniFlowUser({
    required this.id,
    required this.email,
    required this.name,
    required this.accountType,
    required this.role,
    this.university,
    this.program,
    this.level,
    this.country,
    this.username,
    this.avatarFileId,
  });

  UniFlowUser copyWith({String? name, String? username, String? avatarFileId}) {
    return UniFlowUser(
      id: id,
      email: email,
      name: name ?? this.name,
      accountType: accountType,
      role: role,
      university: university,
      program: program,
      level: level,
      country: country,
      username: username ?? this.username,
      avatarFileId: avatarFileId ?? this.avatarFileId,
    );
  }
}
