import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'categories_event.dart';
part 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc() : super(CategoriesInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<RefreshCategories>(_onRefreshCategories);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(CategoriesLoading());
    try {
      final querySnapshot = await AppFirestore.categoriesCollectionRef.get();
      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromQuerySnapshot(doc))
          .toList();
      emit(CategoriesLoaded(categories: categories));
    } catch (e) {
      emit(CategoriesError(message: e.toString()));
    }
  }

  Future<void> _onRefreshCategories(
    RefreshCategories event,
    Emitter<CategoriesState> emit,
  ) async {
    try {
      final querySnapshot = await AppFirestore.categoriesCollectionRef.get();
      final categories = querySnapshot.docs
          .map((doc) => CategoryModel.fromQuerySnapshot(doc))
          .toList();
      emit(CategoriesLoaded(categories: categories));
    } catch (e) {
      emit(CategoriesError(message: e.toString()));
    }
  }
}
