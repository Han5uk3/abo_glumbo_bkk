import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/banner.dart';

class HomeCarouselWidget extends StatefulWidget {
  const HomeCarouselWidget({super.key, required this.banners});
  final List<BannerModel> banners;

  @override
  State<HomeCarouselWidget> createState() => _HomeCarouselWidgetState();
}

class _HomeCarouselWidgetState extends State<HomeCarouselWidget> {
  int _currentIndex = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) {
      return;
    }

    try {
      // Ensure URL has a scheme (http/https)
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final Uri uri = Uri.parse(formattedUrl);

      // Try to launch with externalApplication mode first
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        // If externalApplication fails, try with platformDefault
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (!launched) {
        _showErrorMessage('Unable to open link');
      }
    } catch (e) {
      _showErrorMessage('Failed to open link');
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return Column(
        children: [
          const SizedBox(
            height: 140,
            child: Center(child: Loader(color: Colors.white)),
          ),
          const SizedBox(height: 15),
          AnimatedSmoothIndicator(
            activeIndex: _currentIndex,
            curve: Curves.linear,
            count: 1,
            effect: ExpandingDotsEffect(
              expansionFactor: 1.1,
              activeDotColor: AppColors.secondary,
              dotColor: AppColors.grey1,
              dotHeight: 3,
              dotWidth: 15,
              spacing: 8,
            ),
            onDotClicked: (index) {
              if (mounted) {
                _controller.animateToPage(index);
              }
            },
          ),
        ],
      );
    }

    // Filter banners with valid images
    final validBanners = widget.banners
        .where(
          (item) =>
              item.image != null &&
              item.image!.isNotEmpty &&
              Uri.tryParse(item.image!) != null &&
              Uri.tryParse(item.image!)!.hasAbsolutePath,
        )
        .toList();

    if (validBanners.isEmpty) {
      return Column(
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
              image: DecorationImage(
                image: AssetImage("assets/images/living-room-2732939_1280.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 15),
          AnimatedSmoothIndicator(
            activeIndex: _currentIndex,
            curve: Curves.linear,
            count: 2,
            effect: ExpandingDotsEffect(
              expansionFactor: 1.1,
              activeDotColor: AppColors.secondary,
              dotColor: AppColors.grey1,
              dotHeight: 3,
              dotWidth: 15,
              spacing: 8,
            ),
            onDotClicked: (index) {
              if (mounted) {
                _controller.animateToPage(index);
              }
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        CarouselSlider(
          items: validBanners
              .map(
                (item) => GestureDetector(
                  onTap: () => _launchURL(item.url ?? ''),
                  child: Container(
                    width: double.maxFinite,
                    height: 140,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item.image!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          carouselController: _controller,
          options: CarouselOptions(
            height: 140.0,
            autoPlay: true,
            enlargeCenterPage: true,
            autoPlayCurve: Curves.easeInQuad,
            enableInfiniteScroll: validBanners.length > 1,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            viewportFraction: 1,
            onPageChanged: (index, reason) {
              if (mounted) {
                setState(() => _currentIndex = index);
              }
            },
          ),
        ),
        const SizedBox(height: 15),
        AnimatedSmoothIndicator(
          activeIndex: _currentIndex,
          curve: Curves.linear,
          count: validBanners.length,
          effect: ExpandingDotsEffect(
            expansionFactor: 1.1,
            activeDotColor: AppColors.secondary,
            dotColor: AppColors.grey1,
            dotHeight: 3,
            dotWidth: 15,
            spacing: 8,
          ),
          onDotClicked: (index) {
            if (mounted) {
              _controller.animateToPage(index);
            }
          },
        ),
      ],
    );
  }
}
