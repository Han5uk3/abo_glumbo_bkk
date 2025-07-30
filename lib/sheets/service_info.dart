import 'package:abo_glumbo_bbk/common_widgets/service_tile.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<bool?> showServiceBottomSheet(
  BuildContext context, {
  required ServiceModel service,
}) async {
  bool? res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      return ServiceInfoSheet(service: service);
    },
  );

  return res;
}

class ServiceInfoSheet extends StatefulWidget {
  final ServiceModel service;
  const ServiceInfoSheet({super.key, required this.service});

  @override
  State<ServiceInfoSheet> createState() => _ServiceInfoSheetState();
}

class _ServiceInfoSheetState extends State<ServiceInfoSheet> {
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
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: safePadding.bottom + 3),
        child: BlocBuilder<AccountBloc, AccountState>(
          buildWhen: (previous, current) {
            // Only rebuild if THIS specific service's favorite status changed
            if (current is CustomerDataLoaded &&
                previous is CustomerDataLoaded) {
              final wasServiceFavorite = previous.customerData.favourites
                  .contains(widget.service.id);
              final isServiceFavorite = current.customerData.favourites
                  .contains(widget.service.id);

              // Only rebuild if THIS service's favorite status specifically changed
              return wasServiceFavorite != isServiceFavorite;
            }

            // Initial load
            return current is CustomerDataLoaded &&
                previous is! CustomerDataLoaded;
          },
          builder: (context, accountState) {
            bool isFavorite = false;
            if (accountState is CustomerDataLoaded) {
              isFavorite = accountState.customerData.favourites.contains(
                widget.service.id,
              );
            }

            return ServiceTile(
              key: ValueKey('service_info_tile_${widget.service.id}'),
              service: widget.service,
              isFavorite: isFavorite,
              isGuestUser: LocalStoreHelper.getGuestUser(),
              onFavPressed: () {
                if (LocalStoreHelper.getGuestUser()) {
                  SignUpAlertForGuestUsers().showSignUpAlert(context);
                } else {
                  context.read<AccountBloc>().add(
                    ToggleFavoriteService(service: widget.service),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
