import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/account_providers.dart';
import '../../../data/local/app_database.dart';

// A new UID selects a new stream immediately; prior account data is never
// retained as the loading value for the newly selected account.
final _documentsForAccountProvider = StreamProvider.autoDispose
    .family<List<LocalDocument>, String>(
      (ref, uid) => ref.watch(documentRepositoryProvider).watch(uid),
    );

final savedDocumentsProvider =
    Provider.autoDispose<AsyncValue<List<LocalDocument>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      return uid == null
          ? const AsyncData([])
          : ref.watch(_documentsForAccountProvider(uid));
    });
