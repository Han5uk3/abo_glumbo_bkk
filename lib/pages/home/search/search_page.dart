import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/home/search/bloc/search_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/search/model/filter_criteria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchView extends StatefulWidget {
  final String? initialQuery;

  const SearchView({
    super.key,
    this.initialQuery,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SearchBloc>().add(SearchQueryChanged(widget.initialQuery!));
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SearchAppBar(
        controller: _searchController,
        onSearchChanged: (query) {
          context.read<SearchBloc>().add(SearchQueryChanged(query));
        },
        onFilterPressed: () => _showFilterBottomSheet(context),
      ),
      body: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state is SearchError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SearchContent(state: state);
        },
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: BlocProvider.of<SearchBloc>(context),
        child: const FilterBottomSheet(),
      ),
    );
  }
}


class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;

  const SearchAppBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.onFilterPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(top: 8),
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            final hasActiveFilters = state is SearchSuccess && state.hasActiveFilters;
            
            return SearchBar(
              controller: controller,
              hintText: 'Search services...', // Use localization
              textInputAction: TextInputAction.search,
              autoFocus: true,
              onChanged: onSearchChanged,
              leading: BackButton(
                color: Colors.black87,
                onPressed: () => Navigator.of(context).pop(),
              ),
              trailing: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: hasActiveFilters
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600],
                      ),
                      onPressed: onFilterPressed,
                    ),
                    if (hasActiveFilters)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class SearchContent extends StatelessWidget {
  final SearchState state;

  const SearchContent({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      SearchInitial() => const EmptySearchState(),
      SearchLoading() => const Center(child: CircularProgressIndicator()),
      SearchSuccess(:final services, :final query, :final hasActiveFilters) => 
        _buildSuccessState(context, services, query, hasActiveFilters),
      SearchError(:final message) => ErrorState(message: message),
      _ => const EmptySearchState(),
    };
  }

  Widget _buildSuccessState(
    BuildContext context,
    List<ServiceModel> services,
    String? query,
    bool hasActiveFilters,
  ) {
    if ((query == null || query.isEmpty) && !hasActiveFilters) {
      return const EmptySearchState();
    }

    if (services.isEmpty) {
      return const NoResultsState();
    }

    return ServiceList(
      services: services,
      onFavoritePressed: (service) {
        context.read<SearchBloc>().add(FavoriteToggled(service.id ?? ''));
      },
    );
  }
}


class EmptySearchState extends StatelessWidget {
  const EmptySearchState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Start typing to search services',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class NoResultsState extends StatelessWidget {
  const NoResultsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No services found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;

  const ErrorState({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $message',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


class ServiceList extends StatelessWidget {
  final List<ServiceModel> services;
  final ValueChanged<ServiceModel> onFavoritePressed;

  const ServiceList({
    super.key,
    required this.services,
    required this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceTile(
          service: service,
          // onFavoritePressed: () => onFavoritePressed(service),
        );
      },
    );
  }
}


class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterCriteria _currentFilters;

  @override
  void initState() {
    super.initState();
    final state = context.read<SearchBloc>().state;
    _currentFilters = state is SearchSuccess 
        ? state.filters 
        : const FilterCriteria();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add filter sections here
                  const Text('Filter content will go here'),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter Services',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentFilters = const FilterCriteria();
              });
            },
            child: Text(
              'Reset',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                context.read<SearchBloc>().add(FiltersApplied(_currentFilters));
                Navigator.of(context).pop();
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}