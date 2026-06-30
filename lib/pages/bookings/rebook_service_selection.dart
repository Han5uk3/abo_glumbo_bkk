import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/bookings/book_service_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RebookServiceSelection extends StatefulWidget {
  final UserModel technician;

  const RebookServiceSelection({super.key, required this.technician});

  @override
  State<RebookServiceSelection> createState() => _RebookServiceSelectionState();
}

class _RebookServiceSelectionState extends State<RebookServiceSelection> {
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _allServices = [];
  List<CategoryModel> _allCategories = [];
  List<ServiceModel> _filteredServices = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final services = await AppServices.listenToServices().first;
    final categories = await AppServices.listenToCategories().first;

    final technicianRoles = widget.technician.jobRoles ?? [];

    final validServices = services
        .where((s) => technicianRoles.contains(s.category))
        .toList();
    final validCategories = categories
        .where((c) => technicianRoles.contains(c.id))
        .toList();

    if (mounted) {
      setState(() {
        _allServices = validServices;
        _allCategories = validCategories;
        _filteredServices = validServices;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      if (_searchQuery.isEmpty) {
        _filteredServices = _allServices;
      } else {
        _filteredServices = _allServices.where((service) {
          final nameEn = (service.name ?? '').toLowerCase();
          final nameAr = (service.name_ar ?? '').toLowerCase();
          final nameUr = (service.name_ur ?? '').toLowerCase();
          return nameEn.contains(_searchQuery) ||
              nameAr.contains(_searchQuery) ||
              nameUr.contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.selectService,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: Loader())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: l10n.searchServices,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildServiceList()),
              ],
            ),
    );
  }

  Widget _buildServiceList() {
    if (_filteredServices.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.noServicesFound ?? 'No services found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Group filtered services by category
    Map<String, List<ServiceModel>> grouped = {};
    for (var service in _filteredServices) {
      final categoryId = service.category ?? 'Other';
      if (!grouped.containsKey(categoryId)) {
        grouped[categoryId] = [];
      }
      grouped[categoryId]!.add(service);
    }

    final categoryIds = grouped.keys.toList();
    // Sort categories by their name
    categoryIds.sort((a, b) {
      final catA = _allCategories.firstWhere(
        (c) => c.id == a,
        orElse: () =>
            CategoryModel(id: 'Other', name: 'Other', name_ar: 'أخرى'),
      );
      final catB = _allCategories.firstWhere(
        (c) => c.id == b,
        orElse: () =>
            CategoryModel(id: 'Other', name: 'Other', name_ar: 'أخرى'),
      );
      final locale = AppLocalizations.of(context)?.localeName ?? 'en';
      return (catA.nameLocalized(languageCode: locale) ?? '').compareTo(
        catB.nameLocalized(languageCode: locale) ?? '',
      );
    });

    return ListView.builder(
      itemCount: categoryIds.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final catId = categoryIds[index];
        final category = _allCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () =>
              CategoryModel(id: 'Other', name: 'Other', name_ar: 'أخرى'),
        );
        final services = grouped[catId]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                category.nameLocalized(
                      languageCode:
                          AppLocalizations.of(context)?.localeName ?? 'en',
                    ) ??
                    '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            ...services.map((service) => _buildServiceTile(service)),
          ],
        );
      },
    );
  }

  Widget _buildServiceTile(ServiceModel service) {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookServicePage(
              service: service,
              rebookTechnician: widget.technician,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: service.image ?? "",
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.miscellaneous_services,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.nameLocalized(languageCode: locale) ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.descriptionLocalized(languageCode: locale) ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
