import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';

import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class CategoryDetail extends StatefulWidget {
  final CategoryModel? category;
  const CategoryDetail({super.key, this.category});

  @override
  State<CategoryDetail> createState() => _CategoryDetailState();
}

class _CategoryDetailState extends State<CategoryDetail> {
  List<ServiceModel> allServices = [];
  List<ServiceModel> filteredServices = [];

  String? updatingServiceId;
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    _fetchAllServices();
    _ensureCustomerDataLoaded();
    super.initState();
  }

  void _ensureCustomerDataLoaded() {
    final uid = LocalStoreHelper.getUID();
    final isGuest = LocalStoreHelper.getGuestUser();

    if (!isGuest && uid != null && uid.isNotEmpty) {
      final currentState = context.read<AccountBloc>().state;

      if (currentState is! CustomerDataLoaded) {
        context.read<AccountBloc>().add(ListenCustomerData(uid: uid));
      }
    }
  }

  Future<void> _fetchAllServices() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await AppFirestore.servicesCollectionRef
          .where('category', isEqualTo: widget.category?.id)
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint(snapshot.docs.length.toString());

      final services = snapshot.docs.map((e) {
        return ServiceModel.fromQueryDocumentSnapshot(e);
      }).toList();

      setState(() {
        allServices = services;
        filteredServices = services;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.failedToLoadServices ?? ''}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    return BlocListener<AccountBloc, AccountState>(
      listener: (context, state) {
        if (state is FavoriteServiceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating favorite: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state is FavoriteServiceUpdating) {
          setState(() {
            updatingServiceId = state.serviceId;
          });
        }
        if (state is CustomerDataLoaded) {
          setState(() {
            updatingServiceId = null;
          });
        }
      },
      child: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(
                    widget.category?.nameLocalized(
                          languageCode:
                              AppLocalizations.of(context)?.localeName ?? '',
                        ) ??
                        '',
                  ),
                  pinned: true,
                  primary: true,
                  centerTitle: true,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(55),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SearchBar(
                              hintText:
                                  AppLocalizations.of(context)?.searchHere ??
                                  '',
                              onChanged: _filterServices,
                              leading: const Icon(
                                Icons.search,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isLoading)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 11,
                      top: 15,
                      left: 16,
                      right: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${AppLocalizations.of(context)?.availableServices ?? ''} (${filteredServices.length})',
                              style: DMSansFont.textStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                SizedBox(height: 4),
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.secondary,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.costDisclaimer,
                                style: DMSansFont.textStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final service = filteredServices[index];

                    return BlocBuilder<AccountBloc, AccountState>(
                      buildWhen: (previous, current) {
                        if (current is CustomerDataLoaded &&
                            previous is CustomerDataLoaded) {
                          final wasServiceFavorite = previous
                              .customerData
                              .favourites
                              .contains(service.id);
                          final isServiceFavorite = current
                              .customerData
                              .favourites
                              .contains(service.id);

                          return wasServiceFavorite != isServiceFavorite;
                        }

                        return current is CustomerDataLoaded &&
                            previous is! CustomerDataLoaded;
                      },
                      builder: (context, accountState) {
                        return ServiceTile(
                          isfromHome: false,
                          key: ValueKey('service_tile_${service.id}'),
                          isGuestUser: LocalStoreHelper.getGuestUser(),
                          service: service,
                          onFavPressed: () {
                            if (LocalStoreHelper.getGuestUser()) {
                              SignUpAlertForGuestUsers().showSignUpAlert(
                                context,
                              );
                            } else {
                              context.read<AccountBloc>().add(
                                ToggleFavoriteService(service: service),
                              );
                            }
                          },
                        );
                      },
                    );
                  }, childCount: filteredServices.length),
                ),
                SliverToBoxAdapter(child: SizedBox(height: safePadding.bottom)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _filterServices(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<ServiceModel> filtered = allServices;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((service) {
        final query = searchQuery.toLowerCase();
        final serviceName = isArabic
            ? service.name_ar?.toLowerCase() ?? ''
            : service.name?.toLowerCase() ?? '';
        final serviceDescription = service.description?.toLowerCase() ?? '';

        return serviceName.contains(query) ||
            serviceDescription.contains(query);
      }).toList();
    }

    filteredServices = filtered;
  }
}
