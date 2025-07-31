import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationShowingWidget extends StatefulWidget {
  const LocationShowingWidget({super.key});

  @override
  State<LocationShowingWidget> createState() => _LocationShowingWidgetState();
}

class _LocationShowingWidgetState extends State<LocationShowingWidget> {
  String? _location;
  bool _hasAttemptedFetch = false;
  static bool _hasSuccessfullyFetched =
      false; // Make it static to persist across widget rebuilds

  @override
  void initState() {
    super.initState();
    // Fetch location automatically only on the very first time
    if (!_hasSuccessfullyFetched) {
      _fetchLocation();
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _hasAttemptedFetch = true;
    });

    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (!mounted) return;

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showSnackBar(
          AppLocalizations.of(context)?.locationPermissionDenied ?? '',
          context,
          backgroundColor: AppColors.red,
        );
        return;
      }

      if (mounted) {
        context.read<AccountBloc>().add(UpdateCustomerLocation());
      }
    } catch (e) {
      if (!mounted) return;

      showSnackBar(
        AppLocalizations.of(context)?.locationPermissionDeniedForever ?? '',
        context,
        backgroundColor: AppColors.red,
      );
      debugPrint('Error fetching location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        if (state is UpdateCustomerLocationSuccess) {
          _location = state.locationName;
          _hasSuccessfullyFetched = true; // Mark as successfully fetched
        } else if (state is UpdateCustomerLocationError) {
          _location = state.error;
        }

        // Determine what text to show
        String displayText;
        if (state is UpdateCustomerLocationLoading) {
          displayText = 'Loading...';
        } else if (_location != null && _location!.isNotEmpty) {
          displayText = _location!;
        } else if (_hasAttemptedFetch) {
          displayText = 'Unable to get location';
        } else {
          displayText = 'Tap refresh to get location';
        }

        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  // Only fetch when user manually clicks refresh
                  _fetchLocation();
                },
                child: state is UpdateCustomerLocationLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white70,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 16,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
