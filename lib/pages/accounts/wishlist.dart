import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WishListPage extends StatefulWidget {
  const WishListPage({super.key});

  @override
  State<WishListPage> createState() => _WishListPageState();
}

class _WishListPageState extends State<WishListPage> {
  @override
  void initState() {
    super.initState();
    _ensureCustomerDataLoaded();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.wishlist ?? ''),
        centerTitle: true,
      ),
      body: BlocListener<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is FavoriteServiceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating favorite: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: StreamBuilder<List<ServiceModel>>(
          stream: AppServices.listenToWishlist(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Loader(size: 32, color: Theme.of(context).primaryColor),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final services = snapshot.data ?? [];
            if (services.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)?.noWishlistItems ??
                      'No items in wishlist',
                ),
              );
            }
            return ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];

                return BlocBuilder<AccountBloc, AccountState>(
                  buildWhen: (previous, current) {
                    // Only rebuild this specific tile if THIS specific service's favorite status changed
                    if (current is CustomerDataLoaded &&
                        previous is CustomerDataLoaded) {
                      final wasServiceFavorite = previous
                          .customerData
                          .favourites
                          .contains(service.id);
                      final isServiceFavorite = current.customerData.favourites
                          .contains(service.id);

                      // Only rebuild if THIS service's favorite status specifically changed
                      return wasServiceFavorite != isServiceFavorite;
                    }

                    // Initial load
                    return current is CustomerDataLoaded &&
                        previous is! CustomerDataLoaded;
                  },
                  builder: (context, accountState) {
                    return ServiceTile(isfromHome: false,
                      key: ValueKey('wishlist_service_tile_${service.id}'),
                      service: service,
                      isGuestUser: LocalStoreHelper.getGuestUser(),
                      onFavPressed: () {
                        if (LocalStoreHelper.getGuestUser()) {
                          SignUpAlertForGuestUsers().showSignUpAlert(context);
                        } else {
                          context.read<AccountBloc>().add(
                            ToggleFavoriteService(service: service),
                          );
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
