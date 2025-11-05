extension Filter<T> on Stream<List<T>> {
  Stream<List<T>> filter(bool Function(T) test) async* {
    await for (final list in this) {
      yield list.where(test).toList();
    }
  }
}
