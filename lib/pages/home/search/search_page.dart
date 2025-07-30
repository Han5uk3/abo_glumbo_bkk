import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/categories/bloc/categories_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/search/bloc/search_bloc.dart';
import 'package:abo_glumbo_bbk/pages/home/search/model/filter_criteria.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query});
  final String? query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  bool isGuestUser = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _checkUserGuestStatus();
      context.read<CategoriesBloc>().add(LoadCategories());
      context.read<SearchBloc>().add(
        SearchInitialized(initialQuery: widget.query),
      );
      if (widget.query != null) {
        _searchController.text = widget.query!;
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkUserGuestStatus() async {
    final isGuest = LocalStoreHelper.getGuestUser();
    setState(() {
      isGuestUser = isGuest;
    });
  }

  void _onSearchChanged(String query) {
    context.read<SearchBloc>().add(SearchQueryChanged(query));
  }

  void _openFilter() async {
    final categories = context.read<CategoriesBloc>().state;
    List<CategoryModel> availableCategories = [];

    if (categories is CategoriesLoaded) {
      availableCategories = categories.categories;
    }

    final result = await showFilterBottomSheet(
      context,
      availableCategories: availableCategories,
    );

    if (result != null) {
      final filters = FilterCriteria(
        selectedDistricts: result['districts'] as Set<String>? ?? {},
        selectedRatings: result['ratings'] as Set<int>? ?? {},
        selectedPriceRanges: result['prices'] as Set<int>? ?? {},
        selectedCategories: result['categories'] as Set<String>? ?? {},
      );
      context.read<SearchBloc>().add(FiltersApplied(filters));
    }
  }

  void _setFavorite(ServiceModel service) {
    if (!isGuestUser) {
      final accountState = context.read<AccountBloc>().state;
      if (accountState is CustomerDataLoaded) {
        context.read<SearchBloc>().add(
          FavoriteToggled(
            serviceId: service.id!,
            customerData: accountState.customerData,
          ),
        );
      }
    } else {
      SignUpAlertForGuestUsers().showSignUpAlert(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        primary: true,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.all(16.0).copyWith(top: 8),
          child: SearchBar(
            controller: _searchController,
            hintText: AppLocalizations.of(context)?.searchServices ?? '',
            textInputAction: TextInputAction.search,
            autoFocus: true,
            onChanged: _onSearchChanged,
            leading: BackButton(
              color: Colors.black87,
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(context).pop();
              },
            ),
            trailing: [
              BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  final hasActiveFilters = state is SearchSuccess
                      ? state.hasActiveFilters
                      : false;
                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: hasActiveFilters
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                        onPressed: _openFilter,
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<SearchBloc, SearchState>(
              listener: (context, state) {
                if (state is SearchError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${AppLocalizations.of(context)?.error ?? ''}: ${state.message}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else if (state is FavoriteUpdateError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${AppLocalizations.of(context)?.error ?? ''}: ${state.message}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is SearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is SearchSuccess) {
                  if (state.services.isEmpty && !state.hasActiveFilters) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.startTyping,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  } else if (state.services.isEmpty) {
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
                            AppLocalizations.of(context)!.noServicesFound,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return ListView.builder(
                      itemCount: state.services.length,
                      itemBuilder: (context, index) {
                        final service = state.services[index];
                        return ServiceTile(
                          isGuestUser: isGuestUser,
                          service: service,
                          onFavPressed: () => _setFavorite(service),
                        );
                      },
                    );
                  }
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.startTyping,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> showFilterBottomSheet(
  BuildContext context, {
  List<CategoryModel>? availableCategories,
}) async {
  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        FilterBottomSheet(availableCategories: availableCategories ?? []),
  );
}

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key, this.availableCategories = const []});

  final List<CategoryModel> availableCategories;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedPriceRange = 'all';
  double _minRating = 0;
  List<String> _selectedCategories = [];
  String _sortBy = 'relevance';

  List<Map<String, dynamic>> get _priceRanges {
    return [
      {'label': AppLocalizations.of(context)!.under50, 'value': 'under_50'},
      {'label': AppLocalizations.of(context)!.from50to100, 'value': '50_100'},
      {'label': AppLocalizations.of(context)!.from100to200, 'value': '100_200'},
      {'label': AppLocalizations.of(context)!.from200to500, 'value': '200_500'},
      {
        'label': AppLocalizations.of(context)!.from500to1000,
        'value': '500_1000',
      },
      {'label': AppLocalizations.of(context)!.above1000, 'value': 'above_1000'},
    ];
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
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.filterServices,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPriceRange = 'all';
                      _minRating = 0;
                      _selectedCategories.clear();
                      _sortBy = 'relevance';
                    });
                  },
                  child: Text(
                    AppLocalizations.of(context)!.reset,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: AppLocalizations.of(context)!.priceRange,
                    icon: Icons.attach_money,
                    child: Column(
                      children: _priceRanges.map((range) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedPriceRange == range['value']
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300]!,
                            ),
                            color: _selectedPriceRange == range['value']
                                ? Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: RadioListTile<String>(
                            title: Text(
                              range['label'],
                              style: TextStyle(
                                fontWeight:
                                    _selectedPriceRange == range['value']
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _selectedPriceRange == range['value']
                                    ? Theme.of(context).primaryColor
                                    : Colors.black87,
                              ),
                            ),
                            value: range['value'],
                            groupValue: _selectedPriceRange,
                            onChanged: (value) {
                              setState(() {
                                _selectedPriceRange = value!;
                              });
                            },
                            activeColor: Theme.of(context).primaryColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    title: AppLocalizations.of(context)!.categories,
                    icon: Icons.category,
                    child: widget.availableCategories.isEmpty
                        ? Text(
                            AppLocalizations.of(context)!.noCategoriesAvailable,
                            style: const TextStyle(color: Colors.grey),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.availableCategories.map((
                              category,
                            ) {
                              final isSelected = _selectedCategories.contains(
                                category.id,
                              );
                              final categoryName =
                                  Directionality.of(context) ==
                                      TextDirection.ltr
                                  ? category.name ?? 'Unknown'
                                  : category.name_ar ??
                                        category.name ??
                                        'Unknown';
                              return FilterChip(
                                label: Text(categoryName),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected && category.id != null) {
                                      _selectedCategories.add(category.id!);
                                    } else if (category.id != null) {
                                      _selectedCategories.remove(category.id!);
                                    }
                                  });
                                },
                                selectedColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.2),
                                checkmarkColor: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[300]!,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                  _buildFilterSection(
                    title: AppLocalizations.of(context)!.minimumRating,
                    icon: Icons.star,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_minRating.toStringAsFixed(1)}+',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (index) {
                            final rating = index + 1;
                            final isSelected = _minRating >= rating;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _minRating = rating.toDouble();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${rating}+',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.cancel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // Convert the price range selection to price range indices
                      Set<int> priceRanges = {};
                      if (_selectedPriceRange != 'all') {
                        switch (_selectedPriceRange) {
                          case 'under_50':
                            priceRanges.add(0);
                            break;
                          case '50_100':
                            priceRanges.add(1);
                            break;
                          case '100_200':
                            priceRanges.add(2);
                            break;
                          case '200_500':
                            priceRanges.add(3);
                            break;
                          case '500_1000':
                          case 'above_1000':
                            priceRanges.add(4);
                            break;
                        }
                      }

                      // Convert rating to set
                      Set<int> ratings = {};
                      if (_minRating > 0) {
                        ratings.add(_minRating.round());
                      }

                      final filtersToApply = {
                        'districts': <String>{},
                        'ratings': ratings,
                        'prices': priceRanges,
                        'categories': _selectedCategories.toSet(),
                      };

                      Navigator.of(context).pop(filtersToApply);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context)!.applyFilters} (${_getFilterCount()})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  int _getFilterCount() {
    int count = 0;
    if (_selectedPriceRange != 'all') count++;
    if (_selectedCategories.isNotEmpty) count++;
    if (_minRating > 0) count++;

    return count;
  }
}
