import 'model.dart';

class DashboardActions {
  final V3Store store;
  final String directory;
  final Future<void> Function() add;
  final Future<void> Function(Item) edit, remove;
  final Future<void> Function(Item) update;
  const DashboardActions({
    required this.store,
    required this.directory,
    required this.add,
    required this.edit,
    required this.remove,
    required this.update,
  });
}
