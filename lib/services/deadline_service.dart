import '../model/task/deadline.dart';
import '../repositories/deadline_repo.dart';
import '../util/interfaces/repository/deadline_repository.dart';
import '../util/interfaces/sortable.dart';

class DeadlineService {
  // This is just default. Switch as needed.
  DeadlineRepository _repository = DeadlineRepo();

  set repository(DeadlineRepository repo) => _repository = repo;

  Future<void> createDeadline({required Deadline deadline}) async =>
      _repository.create(deadline);

  Future<List<Deadline>> getDeadlines() async => _repository.getRepoList();
  Future<List<Deadline>> getDeadlinesBy(
          {required SortableView<Deadline> sorter}) async =>
      _repository.getRepoListBy(sorter: sorter);

  Future<Deadline?> getDeadlineByID({required int id}) =>
      _repository.getByID(id: id);

  Future<List<Deadline>> getOverdues() async => _repository.getOverdues();

  Future<void> updateDeadline({required Deadline deadline}) async =>
      _repository.update(deadline);
  Future<void> updateBatch({required List<Deadline> deadlines}) async =>
      _repository.updateBatch(deadlines);

  Future<void> deleteDeadline({required Deadline deadline}) async =>
      _repository.delete(deadline);

  Future<void> clearDeletesLocalRepo() async => _repository.deleteLocal();

  Future<void> syncRepo() async => _repository.syncRepo();

  Future<void> reorderDeadlines(
      {required List<Deadline> deadlines,
      required int oldIndex,
      required int newIndex}) async {
    if (oldIndex < newIndex) {
      newIndex--;
    }
    Deadline d = deadlines.removeAt(oldIndex);
    deadlines.insert(newIndex, d);
    for (int i = 0; i < deadlines.length; i++) {
      deadlines[i].customViewIndex = i;
    }
    _repository.updateBatch(deadlines);
  }
}
