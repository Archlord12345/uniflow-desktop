import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';

class AcademicRepository {
  final AppwriteService _service;

  AcademicRepository(this._service);

  Future<List<AcademicCourse>> getCourses() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_courses',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicCourse.fromDocument(doc)).toList();
  }

  Future<List<AcademicSchedule>> getSchedules() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_schedules',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicSchedule.fromDocument(doc)).toList();
  }

  Future<List<AcademicGrade>> getAllGrades() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_grades',
      queries: [Query.limit(500)],
    );
    return response.documents.map((doc) => AcademicGrade.fromDocument(doc)).toList();
  }

  Future<List<AcademicAssignment>> getAssignments() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_assignments',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicAssignment.fromDocument(doc)).toList();
  }

  Future<Map<String, dynamic>> getGlobalStats() async {
    // Dans une version de production, on utiliserait une Appwrite Function
    // ou une agrégation. Ici on fait des listDocuments avec limit(0) pour avoir le total.
    final students = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_directory',
      queries: [Query.equal('role', 'STUDENT'), Query.limit(1)],
    );
    final teachers = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_directory',
      queries: [Query.equal('role', 'TEACHER'), Query.limit(1)],
    );
    final courses = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_courses',
      queries: [Query.limit(1)],
    );
    final sessions = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'attendance_sessions',
      queries: [Query.limit(1)],
    );

    return {
      'studentCount': students.total,
      'teacherCount': teachers.total,
      'courseCount': courses.total,
      'sessionCount': sessions.total,
    };
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AcademicRepository(service);
});
