import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../models/appwrite_models.dart';

final currentUserProvider = StateProvider<UniFlowUser?>((ref) => null);

final sessionCheckProvider = FutureProvider<void>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final user = await authRepo.getCurrentUser();
  ref.read(currentUserProvider.notifier).state = user;
});
