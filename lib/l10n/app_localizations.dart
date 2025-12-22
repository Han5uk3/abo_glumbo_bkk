import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'abo glumbo'**
  String get appName;

  /// No description provided for @appLoginCaption.
  ///
  /// In en, this message translates to:
  /// **'Your go-to app for finding qualified professionals.'**
  String get appLoginCaption;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @byContinuingYouAgreeToOur.
  ///
  /// In en, this message translates to:
  /// **'By Continuing you agree to our'**
  String get byContinuingYouAgreeToOur;

  /// No description provided for @termsOfUseAndPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **' Terms of use & privacy policy'**
  String get termsOfUseAndPrivacyPolicy;

  /// No description provided for @otpAutoVerified.
  ///
  /// In en, this message translates to:
  /// **'OTP Auto Verified'**
  String get otpAutoVerified;

  /// No description provided for @somethingWentWrongTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, Try again'**
  String get somethingWentWrongTryAgain;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP Sent'**
  String get otpSent;

  /// No description provided for @highestRating.
  ///
  /// In en, this message translates to:
  /// **'Highest Rating'**
  String get highestRating;

  /// No description provided for @nearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get nearest;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @issueMedia.
  ///
  /// In en, this message translates to:
  /// **'Issue Media'**
  String get issueMedia;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @technicianIsBusy.
  ///
  /// In en, this message translates to:
  /// **'Technician is busy'**
  String get technicianIsBusy;

  /// No description provided for @technicianIsBusyatThisTime.
  ///
  /// In en, this message translates to:
  /// **'Technician is busy at this time'**
  String get technicianIsBusyatThisTime;

  /// No description provided for @yourTechnicianIsMovingToYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your technician is moving to your location.'**
  String get yourTechnicianIsMovingToYourLocation;

  /// No description provided for @issueImage.
  ///
  /// In en, this message translates to:
  /// **'Issue Image'**
  String get issueImage;

  /// No description provided for @loadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading Video'**
  String get loadingVideo;

  /// No description provided for @tapForLiveLocationTracking.
  ///
  /// In en, this message translates to:
  /// **'Tap for Live Location Tracking'**
  String get tapForLiveLocationTracking;

  /// No description provided for @allMarkedAsRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read'**
  String get allMarkedAsRead;

  /// No description provided for @failedToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get failedToLoadVideo;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @markAllAsReadMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark all notifications as read?'**
  String get markAllAsReadMessage;

  /// No description provided for @mostOrders.
  ///
  /// In en, this message translates to:
  /// **'Most Orders'**
  String get mostOrders;

  /// No description provided for @anErrorOccurredPleaseTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'An error occurred, please try again later'**
  String get anErrorOccurredPleaseTryAgainLater;

  /// No description provided for @pleaseEnterAValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterAValidPhoneNumber;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get invalidOtp;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP verification'**
  String get otpVerification;

  /// No description provided for @enterTheOtpSentToTheNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to the number '**
  String get enterTheOtpSentToTheNumber;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @areYouSureYouWantToConfirmThisPayment.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to confirm this payment?'**
  String get areYouSureYouWantToConfirmThisPayment;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @areYouSureYouWantToLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureYouWantToLogout;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @failedToLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories'**
  String get failedToLoadCategories;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myBooking.
  ///
  /// In en, this message translates to:
  /// **'My Booking'**
  String get myBooking;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @searchHere.
  ///
  /// In en, this message translates to:
  /// **'Search here'**
  String get searchHere;

  /// No description provided for @availableServices.
  ///
  /// In en, this message translates to:
  /// **'Available services'**
  String get availableServices;

  /// No description provided for @failedToLoadLocations.
  ///
  /// In en, this message translates to:
  /// **'Failed to load locations'**
  String get failedToLoadLocations;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get failedToUpdateProfile;

  /// No description provided for @profileManagement.
  ///
  /// In en, this message translates to:
  /// **'Profile Management'**
  String get profileManagement;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @enterAValidName.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name'**
  String get enterAValidName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @emailIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailIsRequired;

  /// No description provided for @enterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterAValidEmail;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @locationIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Location is required'**
  String get locationIsRequired;

  /// No description provided for @buildingNumber.
  ///
  /// In en, this message translates to:
  /// **'Building Number'**
  String get buildingNumber;

  /// No description provided for @buildingNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Building number is required'**
  String get buildingNumberIsRequired;

  /// No description provided for @streetName.
  ///
  /// In en, this message translates to:
  /// **'Street Name'**
  String get streetName;

  /// No description provided for @streetNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Street name is required'**
  String get streetNameIsRequired;

  /// No description provided for @districtName.
  ///
  /// In en, this message translates to:
  /// **'District Name'**
  String get districtName;

  /// No description provided for @districtNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'District name is required'**
  String get districtNameIsRequired;

  /// No description provided for @cityNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'City name is required'**
  String get cityNameIsRequired;

  /// No description provided for @postcode.
  ///
  /// In en, this message translates to:
  /// **'Postcode'**
  String get postcode;

  /// No description provided for @postcodeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Postcode is required'**
  String get postcodeIsRequired;

  /// No description provided for @extensionNumber.
  ///
  /// In en, this message translates to:
  /// **'Extension Number'**
  String get extensionNumber;

  /// No description provided for @extensionNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Extension number is required'**
  String get extensionNumberIsRequired;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get accountCreatedSuccessfully;

  /// No description provided for @failedToCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to create account'**
  String get failedToCreateAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @pleaseFillTheInputBelowHereToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please fill the input below here to continue'**
  String get pleaseFillTheInputBelowHereToContinue;

  /// No description provided for @failedToLoadContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load content'**
  String get failedToLoadContent;

  /// No description provided for @noAddress.
  ///
  /// In en, this message translates to:
  /// **'No address'**
  String get noAddress;

  /// No description provided for @searchForAService.
  ///
  /// In en, this message translates to:
  /// **'Search for a service'**
  String get searchForAService;

  /// No description provided for @jobCategories.
  ///
  /// In en, this message translates to:
  /// **'Job categories'**
  String get jobCategories;

  /// No description provided for @failedToLoadDataPleaseTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data. Please try again later.'**
  String get failedToLoadDataPleaseTryAgainLater;

  /// No description provided for @noBookingsFound.
  ///
  /// In en, this message translates to:
  /// **'No bookings found.'**
  String get noBookingsFound;

  /// No description provided for @searchServices.
  ///
  /// In en, this message translates to:
  /// **'Search services'**
  String get searchServices;

  /// No description provided for @noServicesInYourWishlist.
  ///
  /// In en, this message translates to:
  /// **'No services in your wishlist'**
  String get noServicesInYourWishlist;

  /// No description provided for @failedToSaveBooking.
  ///
  /// In en, this message translates to:
  /// **'Failed to save booking'**
  String get failedToSaveBooking;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afterNoon.
  ///
  /// In en, this message translates to:
  /// **'After noon'**
  String get afterNoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @serviceBookedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Service booked successfully'**
  String get serviceBookedSuccessfully;

  /// No description provided for @checkForBookingStatus.
  ///
  /// In en, this message translates to:
  /// **'Check your booking status in \'My Bookings\' section'**
  String get checkForBookingStatus;

  /// No description provided for @selectDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get selectDateTime;

  /// No description provided for @completeYourBooking.
  ///
  /// In en, this message translates to:
  /// **'Complete your booking'**
  String get completeYourBooking;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @availableTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Available time slot'**
  String get availableTimeSlot;

  /// No description provided for @addNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get addNotes;

  /// No description provided for @paymentMode.
  ///
  /// In en, this message translates to:
  /// **'Payment mode'**
  String get paymentMode;

  /// No description provided for @cashInHand.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand'**
  String get cashInHand;

  /// No description provided for @netBankingUpiCard.
  ///
  /// In en, this message translates to:
  /// **'Net banking / UPI /Card'**
  String get netBankingUpiCard;

  /// No description provided for @pleaseSelectADate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date'**
  String get pleaseSelectADate;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get bookAppointment;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @reviewSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully.'**
  String get reviewSubmittedSuccessfully;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get anErrorOccurred;

  /// No description provided for @submitAReview.
  ///
  /// In en, this message translates to:
  /// **'Submit a review'**
  String get submitAReview;

  /// No description provided for @overallRating.
  ///
  /// In en, this message translates to:
  /// **'Overall rating'**
  String get overallRating;

  /// No description provided for @writeYourReviewHere.
  ///
  /// In en, this message translates to:
  /// **'Write your review here'**
  String get writeYourReviewHere;

  /// No description provided for @pleaseWriteAReview.
  ///
  /// In en, this message translates to:
  /// **'Please write a review'**
  String get pleaseWriteAReview;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get bookingCancelled;

  /// No description provided for @failedToCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel booking'**
  String get failedToCancelBooking;

  /// No description provided for @areYouSureToWanttoCancelthisBooking.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to want to cancel this booking?'**
  String get areYouSureToWanttoCancelthisBooking;

  /// No description provided for @cancellationOnlyAvailableUntilTechnicianAccepts.
  ///
  /// In en, this message translates to:
  /// **'Cancellation only available until the technician accepts'**
  String get cancellationOnlyAvailableUntilTechnicianAccepts;

  /// No description provided for @youWillBeRefundedTheFullAmount.
  ///
  /// In en, this message translates to:
  /// **'You will be refunded the full amount'**
  String get youWillBeRefundedTheFullAmount;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get yesCancel;

  /// No description provided for @failedToLoadServices.
  ///
  /// In en, this message translates to:
  /// **'Failed to load services'**
  String get failedToLoadServices;

  /// No description provided for @writeAReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeAReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review Submitted'**
  String get reviewSubmitted;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// No description provided for @requestService.
  ///
  /// In en, this message translates to:
  /// **'Request service'**
  String get requestService;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @areYouSureYouWantToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the account permenantly'**
  String get areYouSureYouWantToDeleteAccount;

  /// No description provided for @signUpLater.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get signUpLater;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @visualizeYourIssue.
  ///
  /// In en, this message translates to:
  /// **'Visualize your issue'**
  String get visualizeYourIssue;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @addImageOrVideoOfIssue.
  ///
  /// In en, this message translates to:
  /// **'Add Image or Video of Issue'**
  String get addImageOrVideoOfIssue;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'Payment by card'**
  String get cards;

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Payment by Apple Pay'**
  String get applePay;

  /// No description provided for @completedBold.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedBold;

  /// No description provided for @paymentProcessedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been processed successfully.'**
  String get paymentProcessedSuccessfully;

  /// No description provided for @cashOnHands.
  ///
  /// In en, this message translates to:
  /// **'Payment in cash'**
  String get cashOnHands;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @processingPayment.
  ///
  /// In en, this message translates to:
  /// **'Processing Payment'**
  String get processingPayment;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get amountPaid;

  /// No description provided for @reviewNow.
  ///
  /// In en, this message translates to:
  /// **'Review Now'**
  String get reviewNow;

  /// No description provided for @chooseYourTechnician.
  ///
  /// In en, this message translates to:
  /// **'Choose your technician'**
  String get chooseYourTechnician;

  /// No description provided for @chooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose Source'**
  String get chooseSource;

  /// No description provided for @noTechniciansFoundMatchingYourSearch.
  ///
  /// In en, this message translates to:
  /// **'No technicians found matching your search'**
  String get noTechniciansFoundMatchingYourSearch;

  /// No description provided for @searchTechnicians.
  ///
  /// In en, this message translates to:
  /// **'Search technicians...'**
  String get searchTechnicians;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @kmaway.
  ///
  /// In en, this message translates to:
  /// **'km away'**
  String get kmaway;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @completedOrders.
  ///
  /// In en, this message translates to:
  /// **'Completed Orders'**
  String get completedOrders;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @inspectionOnly.
  ///
  /// In en, this message translates to:
  /// **'Inspection Only'**
  String get inspectionOnly;

  /// No description provided for @fullService.
  ///
  /// In en, this message translates to:
  /// **'Full Service'**
  String get fullService;

  /// No description provided for @selectVideoSource.
  ///
  /// In en, this message translates to:
  /// **'Select video source'**
  String get selectVideoSource;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @noTechniciansFound.
  ///
  /// In en, this message translates to:
  /// **'No Technicians found'**
  String get noTechniciansFound;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @selectImageSource.
  ///
  /// In en, this message translates to:
  /// **'Select image source'**
  String get selectImageSource;

  /// No description provided for @confirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirmPayment;

  /// No description provided for @processingPaymentDesc.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we securely process your transaction'**
  String get processingPaymentDesc;

  /// No description provided for @transactionError.
  ///
  /// In en, this message translates to:
  /// **'Transaction Error'**
  String get transactionError;

  /// No description provided for @transactionErrorDesc.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again later.'**
  String get transactionErrorDesc;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccessful;

  /// No description provided for @paymentSuccessfulDesc.
  ///
  /// In en, this message translates to:
  /// **'Your booking has been processed successfully.'**
  String get paymentSuccessfulDesc;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Booking could not be saved. Please try again.'**
  String get paymentFailedDesc;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// No description provided for @paymentPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your booking is confirmed. Please pay the Technician in cash at the time of service.'**
  String get paymentPendingDesc;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get ok;

  /// No description provided for @signupRequired.
  ///
  /// In en, this message translates to:
  /// **'Signup Required'**
  String get signupRequired;

  /// No description provided for @signUpRequiredDes.
  ///
  /// In en, this message translates to:
  /// **'You\'re currently using the app as a guest. To access more features, please sign up or log in.'**
  String get signUpRequiredDes;

  /// No description provided for @contactSupportOptions.
  ///
  /// In en, this message translates to:
  /// **'Contact Support Options'**
  String get contactSupportOptions;

  /// No description provided for @contactByEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact By Email'**
  String get contactByEmail;

  /// No description provided for @contactByWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Contact By WhatsApp'**
  String get contactByWhatsApp;

  /// No description provided for @invalidVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code'**
  String get invalidVerificationCode;

  /// No description provided for @invalidVerificationId.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification ID. Please request a new OTP.'**
  String get invalidVerificationId;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'OTP expired. Please request a new OTP.'**
  String get otpExpired;

  /// No description provided for @quotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'SMS quota exceeded. Try again later.'**
  String get quotaExceeded;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get tooManyAttempts;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait and try again.'**
  String get tooManyRequests;

  /// No description provided for @internalError.
  ///
  /// In en, this message translates to:
  /// **'An internal error occurred. Please try again later.'**
  String get internalError;

  /// No description provided for @netTechnicianror.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get netTechnicianror;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Try again.'**
  String get verificationFailed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED'**
  String get confirmed;

  /// No description provided for @paymentPendings.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT PENDING'**
  String get paymentPendings;

  /// No description provided for @pastBookings.
  ///
  /// In en, this message translates to:
  /// **'PAST BOOKINGS'**
  String get pastBookings;

  /// No description provided for @startTyping.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search services'**
  String get startTyping;

  /// No description provided for @noServicesFound.
  ///
  /// In en, this message translates to:
  /// **'No services found'**
  String get noServicesFound;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @sar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get sar;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// No description provided for @bookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get bookingDetails;

  /// No description provided for @serviceInformation.
  ///
  /// In en, this message translates to:
  /// **'Service Information'**
  String get serviceInformation;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @servicePrice.
  ///
  /// In en, this message translates to:
  /// **'Service Price'**
  String get servicePrice;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @cancelledBy.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by'**
  String get cancelledBy;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @cancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Reason'**
  String get cancellationReason;

  /// No description provided for @cancelledOn.
  ///
  /// In en, this message translates to:
  /// **'Cancelled on'**
  String get cancelledOn;

  /// No description provided for @cancellationDetails.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Details'**
  String get cancellationDetails;

  /// No description provided for @pleaseEnterCancellationReason.
  ///
  /// In en, this message translates to:
  /// **'Please enter cancellation reason.'**
  String get pleaseEnterCancellationReason;

  /// No description provided for @reasonForCancellation.
  ///
  /// In en, this message translates to:
  /// **'Reason for Cancellation'**
  String get reasonForCancellation;

  /// No description provided for @pricingAndPayment.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Payment'**
  String get pricingAndPayment;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get additionalNotes;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @customerReview.
  ///
  /// In en, this message translates to:
  /// **'Customer Review'**
  String get customerReview;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewedOn.
  ///
  /// In en, this message translates to:
  /// **'Reviewed on'**
  String get reviewedOn;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get cancelled;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @permissionLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch location. Please check permissions.'**
  String get permissionLocation;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @enterServiceLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter service location or tap to fetch current location'**
  String get enterServiceLocation;

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourLocation;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelled;

  /// No description provided for @paymentCancelledDesc.
  ///
  /// In en, this message translates to:
  /// **'You have cancelled the payment.'**
  String get paymentCancelledDesc;

  /// No description provided for @lessthan50SAR.
  ///
  /// In en, this message translates to:
  /// **'Less than 50 SAR'**
  String get lessthan50SAR;

  /// No description provided for @fiftySARto100SAR.
  ///
  /// In en, this message translates to:
  /// **'50 SAR to 100 SAR'**
  String get fiftySARto100SAR;

  /// No description provided for @hundredSARto150SAR.
  ///
  /// In en, this message translates to:
  /// **'100 SAR to 150 SAR'**
  String get hundredSARto150SAR;

  /// No description provided for @onefiftySARto200SAR.
  ///
  /// In en, this message translates to:
  /// **'150 SAR to 200 SAR'**
  String get onefiftySARto200SAR;

  /// No description provided for @morethan200SAR.
  ///
  /// In en, this message translates to:
  /// **'More than 200 SAR'**
  String get morethan200SAR;

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter by'**
  String get filterBy;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get applyFilter;

  /// No description provided for @initializingPayment.
  ///
  /// In en, this message translates to:
  /// **'Initializing Payment...'**
  String get initializingPayment;

  /// No description provided for @paymentWasDeclined.
  ///
  /// In en, this message translates to:
  /// **'Payment was declined'**
  String get paymentWasDeclined;

  /// No description provided for @paymentWasCancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Payment was cancelled by user'**
  String get paymentWasCancelledByUser;

  /// No description provided for @errorInitializingPayment.
  ///
  /// In en, this message translates to:
  /// **'Error initializing payment'**
  String get errorInitializingPayment;

  /// No description provided for @telrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Telr credentials not configured. Please update TelrConfig class.'**
  String get telrNotConfigured;

  /// No description provided for @paymentError.
  ///
  /// In en, this message translates to:
  /// **'Payment Error'**
  String get paymentError;

  /// No description provided for @paymentFailedDesc2.
  ///
  /// In en, this message translates to:
  /// **'Don\'t worry, your money is safe'**
  String get paymentFailedDesc2;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get errorDetails;

  /// No description provided for @orderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderId;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @goToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// No description provided for @bookingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Booking completed!'**
  String get bookingCompleted;

  /// No description provided for @bookingCompletedDesc.
  ///
  /// In en, this message translates to:
  /// **'Transaction completed successfully. Your booking has been confirmed.'**
  String get bookingCompletedDesc;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @copyOrderId.
  ///
  /// In en, this message translates to:
  /// **'Copy Order ID'**
  String get copyOrderId;

  /// No description provided for @orderIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Order ID copied to clipboard'**
  String get orderIdCopied;

  /// No description provided for @didntreciveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive code?'**
  String get didntreciveCode;

  /// No description provided for @filtered.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get filtered;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @pendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment pending. Please pay when the Technician completes the work.'**
  String get pendingPayment;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any notifications yet'**
  String get noNotificationsMessage;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @unexpectedErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedErrorOccurred;

  /// No description provided for @filtersApplied.
  ///
  /// In en, this message translates to:
  /// **'Filters applied'**
  String get filtersApplied;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filtersAppliedText.
  ///
  /// In en, this message translates to:
  /// **'Filters Applied'**
  String get filtersAppliedText;

  /// No description provided for @filterServices.
  ///
  /// In en, this message translates to:
  /// **'Filter Services'**
  String get filterServices;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRange;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// No description provided for @minimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get minimumRating;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @under50.
  ///
  /// In en, this message translates to:
  /// **'Under SAR 50'**
  String get under50;

  /// No description provided for @from50to100.
  ///
  /// In en, this message translates to:
  /// **'SAR 50 - SAR 100'**
  String get from50to100;

  /// No description provided for @from100to200.
  ///
  /// In en, this message translates to:
  /// **'SAR 100 - SAR 200'**
  String get from100to200;

  /// No description provided for @from200to500.
  ///
  /// In en, this message translates to:
  /// **'SAR 200 - SAR 500'**
  String get from200to500;

  /// No description provided for @from500to1000.
  ///
  /// In en, this message translates to:
  /// **'SAR 500 - SAR 1000'**
  String get from500to1000;

  /// No description provided for @above1000.
  ///
  /// In en, this message translates to:
  /// **'Above SAR 1000'**
  String get above1000;

  /// No description provided for @phoneNumberAlreadyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Phone number already updated'**
  String get phoneNumberAlreadyUpdated;

  /// No description provided for @pleaseAddCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Please add country code +966'**
  String get pleaseAddCountryCode;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @phoneNumberAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Phone number already exists'**
  String get phoneNumberAlreadyExists;

  /// No description provided for @selectFilter.
  ///
  /// In en, this message translates to:
  /// **'Select a filter to category'**
  String get selectFilter;

  /// No description provided for @migratingData.
  ///
  /// In en, this message translates to:
  /// **'Migrating your data'**
  String get migratingData;

  /// No description provided for @weAreMigratingYourData.
  ///
  /// In en, this message translates to:
  /// **'We\'re securely transferring all your data to your new number. This process may take a few minutes.'**
  String get weAreMigratingYourData;

  /// No description provided for @pleaseDontCloseTheApp.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the application during this process, as it may lead to loss of your data.'**
  String get pleaseDontCloseTheApp;

  /// No description provided for @transferringData.
  ///
  /// In en, this message translates to:
  /// **'Status: Transferring data...'**
  String get transferringData;

  /// No description provided for @pleaseSelectAValidTime.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid time'**
  String get pleaseSelectAValidTime;

  /// No description provided for @sendingOTP.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP...'**
  String get sendingOTP;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @searchLocations.
  ///
  /// In en, this message translates to:
  /// **'Search locations'**
  String get searchLocations;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select District'**
  String get selectDistrict;

  /// No description provided for @deleteAccoundSnack.
  ///
  /// In en, this message translates to:
  /// **'Deleting Account..., you will be logged out'**
  String get deleteAccoundSnack;

  /// No description provided for @bioMetricAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric'**
  String get bioMetricAuthentication;

  /// No description provided for @chooseServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose Service Address'**
  String get chooseServiceAddress;

  /// No description provided for @pickServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Pick the address where you need the service.'**
  String get pickServiceAddress;

  /// No description provided for @serviceto.
  ///
  /// In en, this message translates to:
  /// **'Service to:'**
  String get serviceto;

  /// No description provided for @selectServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Service Address'**
  String get selectServiceAddress;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @pleaseAddANewAddress.
  ///
  /// In en, this message translates to:
  /// **'Please add a new address'**
  String get pleaseAddANewAddress;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable location services in your device settings.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied. Please enable location permissions in your device settings.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Please enable location permissions in your device settings.'**
  String get locationPermissionDeniedForever;

  /// No description provided for @couldNotGetCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch location. Please check permissions.'**
  String get couldNotGetCurrentLocation;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @unableToGetAddress.
  ///
  /// In en, this message translates to:
  /// **'Unable to get address'**
  String get unableToGetAddress;

  /// No description provided for @couldNotFindLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not find location'**
  String get couldNotFindLocation;

  /// No description provided for @gettingAddress.
  ///
  /// In en, this message translates to:
  /// **'Getting address...'**
  String get gettingAddress;

  /// No description provided for @buildingName.
  ///
  /// In en, this message translates to:
  /// **'Building Name'**
  String get buildingName;

  /// No description provided for @buildingNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Building name is required'**
  String get buildingNameRequired;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameRequired;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @invalidPhoneNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number format'**
  String get invalidPhoneNumberFormat;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get saveAddress;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose Location'**
  String get chooseLocation;

  /// No description provided for @useMyCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useMyCurrentLocation;

  /// No description provided for @addAddressDetails.
  ///
  /// In en, this message translates to:
  /// **'Add address details'**
  String get addAddressDetails;

  /// No description provided for @pleaseSelectServiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select service address'**
  String get pleaseSelectServiceAddress;

  /// No description provided for @paymentDeclined.
  ///
  /// In en, this message translates to:
  /// **'Payment Declined'**
  String get paymentDeclined;

  /// No description provided for @tipAmount.
  ///
  /// In en, this message translates to:
  /// **'Tip Amount'**
  String get tipAmount;

  /// No description provided for @failedToSaveReview.
  ///
  /// In en, this message translates to:
  /// **'Failed to save review'**
  String get failedToSaveReview;

  /// No description provided for @thankTheTechnician.
  ///
  /// In en, this message translates to:
  /// **'Thank the Technician'**
  String get thankTheTechnician;

  /// No description provided for @showAppreciationWithTip.
  ///
  /// In en, this message translates to:
  /// **'Show appreciation with tip'**
  String get showAppreciationWithTip;

  /// No description provided for @enterCustomTipAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter Custom Tip Amount'**
  String get enterCustomTipAmount;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @payInCash.
  ///
  /// In en, this message translates to:
  /// **'Pay in Cash'**
  String get payInCash;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip:'**
  String get tip;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @writeYourReview.
  ///
  /// In en, this message translates to:
  /// **'Write your review'**
  String get writeYourReview;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @submitTip.
  ///
  /// In en, this message translates to:
  /// **'Submit & Tip'**
  String get submitTip;

  /// No description provided for @payWithCard.
  ///
  /// In en, this message translates to:
  /// **'Pay with Card'**
  String get payWithCard;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select rating'**
  String get pleaseSelectRating;

  /// No description provided for @pleaseSelectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Please select payment method'**
  String get pleaseSelectPaymentMethod;

  /// No description provided for @pleaseEnterValidTipAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid tip amount'**
  String get pleaseEnterValidTipAmount;

  /// No description provided for @minimumTipAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum tip amount is SAR 5'**
  String get minimumTipAmount;

  /// No description provided for @pleaseEnterTipAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter tip amount'**
  String get pleaseEnterTipAmount;

  /// No description provided for @submitReviewAndTip.
  ///
  /// In en, this message translates to:
  /// **'Submit Review & Tip'**
  String get submitReviewAndTip;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTracking;

  /// No description provided for @loadingLocation.
  ///
  /// In en, this message translates to:
  /// **'Loading location...'**
  String get loadingLocation;

  /// No description provided for @trackTechnician.
  ///
  /// In en, this message translates to:
  /// **'Track Technician'**
  String get trackTechnician;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Phone number is invalid'**
  String get phoneNumberInvalid;

  /// No description provided for @notificationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Notification Language'**
  String get notificationLanguage;

  /// No description provided for @removeAddress.
  ///
  /// In en, this message translates to:
  /// **'Remove Address'**
  String get removeAddress;

  /// No description provided for @enableBiometricAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Authentication'**
  String get enableBiometricAuthentication;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @biometricNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not supported on this device'**
  String get biometricNotSupported;

  /// No description provided for @pleaseAuthenticateToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please authenticate to continue'**
  String get pleaseAuthenticateToContinue;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authenticationFailed;

  /// No description provided for @biometricNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device'**
  String get biometricNotAvailable;

  /// No description provided for @biometricTemporarilyLocked.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is temporarily locked on this device'**
  String get biometricTemporarilyLocked;

  /// No description provided for @notificationLanguageChanged.
  ///
  /// In en, this message translates to:
  /// **'Notification language changed'**
  String get notificationLanguageChanged;

  /// No description provided for @noWishlistItems.
  ///
  /// In en, this message translates to:
  /// **'No wishlist items'**
  String get noWishlistItems;

  /// No description provided for @errorFillingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error filling profile'**
  String get errorFillingProfile;

  /// No description provided for @errorFetchingLocations.
  ///
  /// In en, this message translates to:
  /// **'Error fetching locations'**
  String get errorFetchingLocations;

  /// No description provided for @bookingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking Success'**
  String get bookingSuccess;

  /// No description provided for @bookingFailed.
  ///
  /// In en, this message translates to:
  /// **'Booking Failed'**
  String get bookingFailed;

  /// No description provided for @bookingCancelError.
  ///
  /// In en, this message translates to:
  /// **'Booking Cancel Error'**
  String get bookingCancelError;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @selectFromSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Select from your saved addresses or add a new one.'**
  String get selectFromSavedAddresses;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

  /// No description provided for @failedToSaveAddress.
  ///
  /// In en, this message translates to:
  /// **'Failed to save address. Please try again.'**
  String get failedToSaveAddress;

  /// No description provided for @unableToGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location'**
  String get unableToGetLocation;

  /// No description provided for @tapRefreshToGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh to get location'**
  String get tapRefreshToGetLocation;

  /// No description provided for @serviceFound.
  ///
  /// In en, this message translates to:
  /// **'Service found'**
  String get serviceFound;

  /// No description provided for @servicesFound.
  ///
  /// In en, this message translates to:
  /// **'Services found'**
  String get servicesFound;

  /// No description provided for @technicianArrivesToLocationIn.
  ///
  /// In en, this message translates to:
  /// **'Technician arrives to location in'**
  String get technicianArrivesToLocationIn;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'away'**
  String get away;

  /// No description provided for @yourTechnicianIsOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Your Technician is on the way'**
  String get yourTechnicianIsOnTheWay;

  /// No description provided for @serviceProvider.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get serviceProvider;

  /// No description provided for @callServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Call Technician'**
  String get callServiceProvider;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @biometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication enabled'**
  String get biometricEnabled;

  /// No description provided for @biometricDisabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication disabled'**
  String get biometricDisabled;

  /// No description provided for @disableBiometricWarning.
  ///
  /// In en, this message translates to:
  /// **'Disabling biometric authentication will prevent you from logging in using fingerprint.'**
  String get disableBiometricWarning;

  /// No description provided for @youWillNeedPhoneOtp.
  ///
  /// In en, this message translates to:
  /// **'You will need to use your phone number and OTP to login.'**
  String get youWillNeedPhoneOtp;

  /// No description provided for @disableBiometric.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometric?'**
  String get disableBiometric;

  /// No description provided for @whatWillBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted:'**
  String get whatWillBeDeleted;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInfo;

  /// No description provided for @bookingHistory.
  ///
  /// In en, this message translates to:
  /// **'Booking history'**
  String get bookingHistory;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @onWarranty.
  ///
  /// In en, this message translates to:
  /// **'On Warranty'**
  String get onWarranty;

  /// No description provided for @warrantyDetails.
  ///
  /// In en, this message translates to:
  /// **'Warranty Details'**
  String get warrantyDetails;

  /// No description provided for @warrantyAppliedOn.
  ///
  /// In en, this message translates to:
  /// **'Warranty Applied On'**
  String get warrantyAppliedOn;

  /// No description provided for @warrantyRequestEscalated.
  ///
  /// In en, this message translates to:
  /// **'Warranty Request Escalated'**
  String get warrantyRequestEscalated;

  /// No description provided for @submitComplaint.
  ///
  /// In en, this message translates to:
  /// **'Submit Complaint'**
  String get submitComplaint;

  /// No description provided for @repairRequestedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Repair Requested Successfully'**
  String get repairRequestedSuccessfully;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires On'**
  String get expiresOn;

  /// No description provided for @expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired On'**
  String get expiredOn;

  /// No description provided for @requestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested On'**
  String get requestedOn;

  /// No description provided for @requestRepair.
  ///
  /// In en, this message translates to:
  /// **'Request Repair'**
  String get requestRepair;

  /// No description provided for @importantInformation.
  ///
  /// In en, this message translates to:
  /// **'Important Information'**
  String get importantInformation;

  /// No description provided for @dayLeft.
  ///
  /// In en, this message translates to:
  /// **'Day Left'**
  String get dayLeft;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'Days Left'**
  String get daysLeft;

  /// No description provided for @repairRequested.
  ///
  /// In en, this message translates to:
  /// **'Repair Requested'**
  String get repairRequested;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @claimStarted.
  ///
  /// In en, this message translates to:
  /// **'Claim Started'**
  String get claimStarted;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @appliedOn.
  ///
  /// In en, this message translates to:
  /// **'Applied On'**
  String get appliedOn;

  /// No description provided for @loadingChat.
  ///
  /// In en, this message translates to:
  /// **'Loading Chat'**
  String get loadingChat;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @rejectedBy.
  ///
  /// In en, this message translates to:
  /// **'Rejected By'**
  String get rejectedBy;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Uploaded documents'**
  String get documents;

  /// No description provided for @allData.
  ///
  /// In en, this message translates to:
  /// **'All associated data'**
  String get allData;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone'**
  String get deleteAccountWarning;

  /// No description provided for @invalidOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP code'**
  String get invalidOtpCode;

  /// No description provided for @errorSavingAddress.
  ///
  /// In en, this message translates to:
  /// **'Error saving address'**
  String get errorSavingAddress;

  /// No description provided for @loadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications...'**
  String get loadingNotifications;

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more...'**
  String get loadingMore;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @errorLoadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Error loading notifications'**
  String get errorLoadingNotifications;

  /// No description provided for @errorRefreshingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Error refreshing notifications'**
  String get errorRefreshingNotifications;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @exitAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the app?'**
  String get exitAppMessage;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitAppTitle;

  /// No description provided for @arrivalTime.
  ///
  /// In en, this message translates to:
  /// **'Arrival Time'**
  String get arrivalTime;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @thankYouMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your rating and tip!\nWe’re happy to serve you and hope to see you again soon.'**
  String get thankYouMessage;

  /// No description provided for @noLiveTrackingAvailable.
  ///
  /// In en, this message translates to:
  /// **'No live tracking available'**
  String get noLiveTrackingAvailable;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// No description provided for @waitingForAgentLocation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for agent location...'**
  String get waitingForAgentLocation;

  /// No description provided for @technicianInfo.
  ///
  /// In en, this message translates to:
  /// **'Technician Info'**
  String get technicianInfo;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @errorLoadingMoreNotifications.
  ///
  /// In en, this message translates to:
  /// **'Error loading more notifications'**
  String get errorLoadingMoreNotifications;

  /// No description provided for @neighbourhood.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood'**
  String get neighbourhood;

  /// No description provided for @neighbourhoodIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood is required'**
  String get neighbourhoodIsRequired;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @noFaqsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No FAQs available.'**
  String get noFaqsAvailable;

  /// No description provided for @doYouAccept.
  ///
  /// In en, this message translates to:
  /// **'Do you accept the Terms and Conditions?'**
  String get doYouAccept;

  /// No description provided for @accountBlocked.
  ///
  /// In en, this message translates to:
  /// **'Account Blocked'**
  String get accountBlocked;

  /// No description provided for @fraudOrRelatedActivities.
  ///
  /// In en, this message translates to:
  /// **'Fraud or related activities'**
  String get fraudOrRelatedActivities;

  /// No description provided for @improperConduct.
  ///
  /// In en, this message translates to:
  /// **'Improper Conduct'**
  String get improperConduct;

  /// No description provided for @violationOfTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Violation of Terms and Conditions'**
  String get violationOfTermsAndConditions;

  /// No description provided for @pleaseContactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Please contact the administrator for more information on why your account was blocked and what steps you may take to unlock it.'**
  String get pleaseContactAdmin;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @pleaseSelectaTechnician.
  ///
  /// In en, this message translates to:
  /// **'Please select a Technician'**
  String get pleaseSelectaTechnician;

  /// No description provided for @chooseTechnician.
  ///
  /// In en, this message translates to:
  /// **'Choose Technician'**
  String get chooseTechnician;

  /// No description provided for @within.
  ///
  /// In en, this message translates to:
  /// **'Within'**
  String get within;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @completeBooking.
  ///
  /// In en, this message translates to:
  /// **'Complete Booking'**
  String get completeBooking;

  /// No description provided for @accountBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked by the admin due to one or more of the following reasons:'**
  String get accountBlockedMessage;

  /// No description provided for @byCreatingAnAccountYouAgreeToOur.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms and Conditions. Please read them carefully before proceeding.'**
  String get byCreatingAnAccountYouAgreeToOur;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed!'**
  String get bookingConfirmed;

  /// No description provided for @bookingSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your booking has been successfully placed'**
  String get bookingSuccessMessage;

  /// No description provided for @bookingId.
  ///
  /// In en, this message translates to:
  /// **'Booking ID'**
  String get bookingId;

  /// No description provided for @serviceDetails.
  ///
  /// In en, this message translates to:
  /// **'Service Details'**
  String get serviceDetails;

  /// No description provided for @inspectionFee.
  ///
  /// In en, this message translates to:
  /// **'Inspection Fee'**
  String get inspectionFee;

  /// No description provided for @technicianDetails.
  ///
  /// In en, this message translates to:
  /// **'Technician Details'**
  String get technicianDetails;

  /// No description provided for @inspectionDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This covers the inspection visit. Total service cost calculated after work is completed.'**
  String get inspectionDisclaimer;

  /// No description provided for @costDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Amount shown is inspection fee. Total service cost determined after completion.'**
  String get costDisclaimer;

  /// No description provided for @noSupportAvailable.
  ///
  /// In en, this message translates to:
  /// **'No support available at this time.'**
  String get noSupportAvailable;

  /// No description provided for @contactByPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact by phone'**
  String get contactByPhone;

  /// No description provided for @pleaseContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Please contact support for more information on why your account was blocked and what steps you may take to unlock it.'**
  String get pleaseContactSupport;

  /// No description provided for @yourAccountHasBeenBlocked.
  ///
  /// In en, this message translates to:
  /// **'Your account has been blocked by the admin due to one or more of the following reasons:'**
  String get yourAccountHasBeenBlocked;

  /// No description provided for @serviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Service Location'**
  String get serviceLocation;

  /// No description provided for @cashPayment.
  ///
  /// In en, this message translates to:
  /// **'Cash Payment'**
  String get cashPayment;

  /// No description provided for @amountToBePaid.
  ///
  /// In en, this message translates to:
  /// **'Amount to be paid'**
  String get amountToBePaid;

  /// No description provided for @balanceToReceive.
  ///
  /// In en, this message translates to:
  /// **'Balance to receive'**
  String get balanceToReceive;

  /// No description provided for @pleaseEnterTheAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Please enter the amount paid'**
  String get pleaseEnterTheAmountPaid;

  /// No description provided for @pleaseEnterAValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterAValidAmount;

  /// No description provided for @amountMustBeAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Amount must be at least'**
  String get amountMustBeAtLeast;

  /// No description provided for @amountMustBeEqualTo.
  ///
  /// In en, this message translates to:
  /// **'Amount must be equal to'**
  String get amountMustBeEqualTo;

  /// No description provided for @noPendingBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no pending bookings at the moment. New booking requests will appear here.'**
  String get noPendingBookingsMessage;

  /// No description provided for @noConfirmedBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'No confirmed bookings yet. Once technician accept your requests, they will appear here.'**
  String get noConfirmedBookingsMessage;

  /// No description provided for @noCompletedBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your completed bookings will appear here once services are finished.'**
  String get noCompletedBookingsMessage;

  /// No description provided for @noPendingPaymentBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no pending payment bookings. This is great!'**
  String get noPendingPaymentBookingsMessage;

  /// No description provided for @noCancelledBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no cancelled bookings. This is great!'**
  String get noCancelledBookingsMessage;

  /// No description provided for @noBookingsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no bookings at the moment.'**
  String get noBookingsMessage;

  /// Message shown when no bookings are found for a specific type
  ///
  /// In en, this message translates to:
  /// **'No {type} bookings'**
  String noBookingFound(String type);

  /// Message explaining the inspection fee amount and payment terms
  ///
  /// In en, this message translates to:
  /// **'Inspection fee: {fee} SAR — paid only after the technician arrives and inspects the issue.'**
  String inspectionFeeNote(String fee);

  /// No description provided for @pleaseSelectAllLocationFields.
  ///
  /// In en, this message translates to:
  /// **'Please select all location fields'**
  String get pleaseSelectAllLocationFields;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get clearFilter;

  /// No description provided for @filterByLocation.
  ///
  /// In en, this message translates to:
  /// **'Filter by Location'**
  String get filterByLocation;

  /// No description provided for @province.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get province;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating Account'**
  String get creatingAccount;

  /// No description provided for @pleaseSelectNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Please select a neighborhood'**
  String get pleaseSelectNeighborhood;

  /// No description provided for @pleaseSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Please select a city'**
  String get pleaseSelectCity;

  /// No description provided for @pleaseSelectProvince.
  ///
  /// In en, this message translates to:
  /// **'Please select a province'**
  String get pleaseSelectProvince;

  /// No description provided for @bookedOn.
  ///
  /// In en, this message translates to:
  /// **'Booked on'**
  String get bookedOn;

  /// No description provided for @acceptedOn.
  ///
  /// In en, this message translates to:
  /// **'Accepted on'**
  String get acceptedOn;

  /// No description provided for @canceledOn.
  ///
  /// In en, this message translates to:
  /// **'Canceled on'**
  String get canceledOn;

  /// No description provided for @completedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed on'**
  String get completedOn;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @completionDetails.
  ///
  /// In en, this message translates to:
  /// **'Completion Details'**
  String get completionDetails;

  /// No description provided for @serviceCost.
  ///
  /// In en, this message translates to:
  /// **'Service Cost'**
  String get serviceCost;

  /// No description provided for @serviceItems.
  ///
  /// In en, this message translates to:
  /// **'Service Items'**
  String get serviceItems;

  /// No description provided for @uploadFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Proof of Completion / Supporting Documents'**
  String get uploadFilesTitle;

  /// No description provided for @inspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get inspection;

  /// No description provided for @invoiceType.
  ///
  /// In en, this message translates to:
  /// **'Invoice Type'**
  String get invoiceType;

  /// No description provided for @warrantyInformation.
  ///
  /// In en, this message translates to:
  /// **'Warranty Information'**
  String get warrantyInformation;

  /// No description provided for @whatsCovered.
  ///
  /// In en, this message translates to:
  /// **'What\'s Covered'**
  String get whatsCovered;

  /// No description provided for @issueone.
  ///
  /// In en, this message translates to:
  /// **'Faulty installation or poor workmanship'**
  String get issueone;

  /// No description provided for @issuetwo.
  ///
  /// In en, this message translates to:
  /// **'Substandard performance by technician'**
  String get issuetwo;

  /// No description provided for @issuethree.
  ///
  /// In en, this message translates to:
  /// **'Same original fault that was repaired'**
  String get issuethree;

  /// No description provided for @issuefour.
  ///
  /// In en, this message translates to:
  /// **'Valid for one time, within 7 days from completion date'**
  String get issuefour;

  /// No description provided for @whatsNotCovered.
  ///
  /// In en, this message translates to:
  /// **'What\'s Not Covered'**
  String get whatsNotCovered;

  /// No description provided for @notissueone.
  ///
  /// In en, this message translates to:
  /// **'Defective spare parts or materials'**
  String get notissueone;

  /// No description provided for @notissuetwo.
  ///
  /// In en, this message translates to:
  /// **'Misuse or tampering after service'**
  String get notissuetwo;

  /// No description provided for @notissuethree.
  ///
  /// In en, this message translates to:
  /// **'Third-party interventions'**
  String get notissuethree;

  /// No description provided for @notissuefour.
  ///
  /// In en, this message translates to:
  /// **'Power surges, water leaks, natural disasters'**
  String get notissuefour;

  /// No description provided for @notissuefive.
  ///
  /// In en, this message translates to:
  /// **'Normal wear and tear'**
  String get notissuefive;

  /// No description provided for @claimText.
  ///
  /// In en, this message translates to:
  /// **'To claim warranty, submit a request through the app within 7 days from service completion. The warranty can be claimed only once.'**
  String get claimText;

  /// No description provided for @warrantyAlertContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to request warranty repair for this service?'**
  String get warrantyAlertContent;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @repairUnderWarranty.
  ///
  /// In en, this message translates to:
  /// **'Repair under warranty'**
  String get repairUnderWarranty;

  /// No description provided for @warrantyRepairSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **' \'Warranty repair request submitted successfully\''**
  String get warrantyRepairSubmittedSuccessfully;

  /// No description provided for @requestRepairUnderWarranty.
  ///
  /// In en, this message translates to:
  /// **'Request repair under warranty'**
  String get requestRepairUnderWarranty;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @technician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get technician;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversation;

  /// No description provided for @errorLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Error loading messages'**
  String get errorLoadingMessages;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chatWithTechnician.
  ///
  /// In en, this message translates to:
  /// **'Chat with Technician'**
  String get chatWithTechnician;

  /// No description provided for @mins.
  ///
  /// In en, this message translates to:
  /// **'mins'**
  String get mins;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get hour;

  /// No description provided for @iddocument.
  ///
  /// In en, this message translates to:
  /// **'ID Document'**
  String get iddocument;

  /// No description provided for @failedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image'**
  String get failedToPickImage;

  /// No description provided for @tapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get tapToUpload;

  /// No description provided for @tapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get tapToView;

  /// No description provided for @rejectedOn.
  ///
  /// In en, this message translates to:
  /// **'Rejected on'**
  String get rejectedOn;

  /// No description provided for @fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching'**
  String get fetching;

  /// No description provided for @issueVideo.
  ///
  /// In en, this message translates to:
  /// **'Issue Video'**
  String get issueVideo;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get hours;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Location Error'**
  String get locationError;

  /// No description provided for @bookingTimeline.
  ///
  /// In en, this message translates to:
  /// **'Booking Timeline'**
  String get bookingTimeline;

  /// No description provided for @escalateWarrantyConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to escalate this warranty issue? This will notify the admin about the delay or rejection.'**
  String get escalateWarrantyConfirmation;

  /// No description provided for @complaintSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Complaint submitted successfully'**
  String get complaintSubmittedSuccessfully;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get createdAt;

  /// No description provided for @customerSubmittedBookingRequest.
  ///
  /// In en, this message translates to:
  /// **'Customer submitted booking request'**
  String get customerSubmittedBookingRequest;

  /// No description provided for @originalServiceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Original Service Completed'**
  String get originalServiceCompleted;

  /// No description provided for @serviceHasBeenSuccessfullyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Service has been successfully completed'**
  String get serviceHasBeenSuccessfullyCompleted;

  /// No description provided for @warrantyRepairRequested.
  ///
  /// In en, this message translates to:
  /// **'Warranty Repair Requested'**
  String get warrantyRepairRequested;

  /// No description provided for @customerRequestedRepairUnderWarranty.
  ///
  /// In en, this message translates to:
  /// **'Customer requested repair under warranty'**
  String get customerRequestedRepairUnderWarranty;

  /// No description provided for @warrantyRepairAccepted.
  ///
  /// In en, this message translates to:
  /// **'Warranty Repair Accepted'**
  String get warrantyRepairAccepted;

  /// No description provided for @technicianAcceptedTheRequest.
  ///
  /// In en, this message translates to:
  /// **'Technician accepted the request'**
  String get technicianAcceptedTheRequest;

  /// No description provided for @trackingStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Tracking Started At'**
  String get trackingStartedAt;

  /// No description provided for @serviceTrackingInitiated.
  ///
  /// In en, this message translates to:
  /// **'Service tracking initiated'**
  String get serviceTrackingInitiated;

  /// No description provided for @trackingStoppedAt.
  ///
  /// In en, this message translates to:
  /// **'Tracking Stopped At'**
  String get trackingStoppedAt;

  /// No description provided for @serviceTrackingStopped.
  ///
  /// In en, this message translates to:
  /// **'Service tracking stopped'**
  String get serviceTrackingStopped;

  /// No description provided for @warrantyRepairCompleted.
  ///
  /// In en, this message translates to:
  /// **'Warranty Repair Completed'**
  String get warrantyRepairCompleted;

  /// No description provided for @technicianCompletedTheRequest.
  ///
  /// In en, this message translates to:
  /// **'Technician completed the request'**
  String get technicianCompletedTheRequest;

  /// No description provided for @unknownTechnician.
  ///
  /// In en, this message translates to:
  /// **'Unknown Technician'**
  String get unknownTechnician;

  /// No description provided for @technicianCancelled.
  ///
  /// In en, this message translates to:
  /// **'Technician Cancelled'**
  String get technicianCancelled;

  /// No description provided for @tryAdjustingYourSearchOrFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get tryAdjustingYourSearchOrFilters;

  /// No description provided for @cancelledByTechnician.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by Technician'**
  String get cancelledByTechnician;

  /// No description provided for @warrantyRejectedByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Warranty Rejected by Admin'**
  String get warrantyRejectedByAdmin;

  /// No description provided for @cancelledByYou.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by You'**
  String get cancelledByYou;

  /// No description provided for @youCancelledThisBooking.
  ///
  /// In en, this message translates to:
  /// **'You cancelled this booking'**
  String get youCancelledThisBooking;

  /// No description provided for @waitingForYourPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Your Payment'**
  String get waitingForYourPayment;

  /// No description provided for @warrantyRejectedByTechnician.
  ///
  /// In en, this message translates to:
  /// **'Warranty Rejected by Technician'**
  String get warrantyRejectedByTechnician;

  /// No description provided for @paymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment Completed'**
  String get paymentCompleted;

  /// No description provided for @paymentSuccessfullyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment has been successfully completed'**
  String get paymentSuccessfullyCompleted;

  /// No description provided for @warrantyRequestWasRejectedByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Warranty request was rejected by admin'**
  String get warrantyRequestWasRejectedByAdmin;

  /// No description provided for @youSubmittedTheBookingRequest.
  ///
  /// In en, this message translates to:
  /// **'You submitted the booking request'**
  String get youSubmittedTheBookingRequest;

  /// No description provided for @warrantyRequestWasRejectedByTechnician.
  ///
  /// In en, this message translates to:
  /// **'Warranty request was rejected by technician'**
  String get warrantyRequestWasRejectedByTechnician;

  /// No description provided for @acceptedAt.
  ///
  /// In en, this message translates to:
  /// **'Accepted At'**
  String get acceptedAt;

  /// No description provided for @serviceProviderConfirmedAppointment.
  ///
  /// In en, this message translates to:
  /// **'Service provider confirmed appointment'**
  String get serviceProviderConfirmedAppointment;

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed At'**
  String get completedAt;

  /// No description provided for @rejectedAt.
  ///
  /// In en, this message translates to:
  /// **'Rejected At'**
  String get rejectedAt;

  /// No description provided for @bookingWasRejectedByServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Booking was rejected by service provider'**
  String get bookingWasRejectedByServiceProvider;

  /// No description provided for @cancelledByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by Customer'**
  String get cancelledByCustomer;

  /// No description provided for @bookingWasCancelledByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Booking was cancelled by customer'**
  String get bookingWasCancelledByCustomer;

  /// No description provided for @serviceInProgress.
  ///
  /// In en, this message translates to:
  /// **'Service In Progress'**
  String get serviceInProgress;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @serviceIsCurrentlyBeingPerformed.
  ///
  /// In en, this message translates to:
  /// **'Service is currently being performed'**
  String get serviceIsCurrentlyBeingPerformed;

  /// No description provided for @waitingForServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Service Provider'**
  String get waitingForServiceProvider;

  /// No description provided for @waitingForTechnicianToStartService.
  ///
  /// In en, this message translates to:
  /// **'Waiting for technician to start service'**
  String get waitingForTechnicianToStartService;

  /// No description provided for @waitingForServiceProviderResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for service provider response'**
  String get waitingForServiceProviderResponse;

  /// No description provided for @waitingForAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Acceptance'**
  String get waitingForAcceptance;

  /// No description provided for @waitingForAdmin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Admin'**
  String get waitingForAdmin;

  /// No description provided for @waitingForAdminToReassign.
  ///
  /// In en, this message translates to:
  /// **'Waiting for admin to reassign technician'**
  String get waitingForAdminToReassign;

  /// No description provided for @introduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get introduction;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @policy1title.
  ///
  /// In en, this message translates to:
  /// **'Data We Collect'**
  String get policy1title;

  /// No description provided for @policy2title.
  ///
  /// In en, this message translates to:
  /// **'How We Use It'**
  String get policy2title;

  /// No description provided for @policy3title.
  ///
  /// In en, this message translates to:
  /// **'Data Sharing'**
  String get policy3title;

  /// No description provided for @terms1title.
  ///
  /// In en, this message translates to:
  /// **'Responsibility for the Request'**
  String get terms1title;

  /// No description provided for @terms2title.
  ///
  /// In en, this message translates to:
  /// **'Inspection Fees'**
  String get terms2title;

  /// No description provided for @terms3title.
  ///
  /// In en, this message translates to:
  /// **'Payment and Final Cost'**
  String get terms3title;

  /// No description provided for @terms4title.
  ///
  /// In en, this message translates to:
  /// **'Warranty (Guarantee)'**
  String get terms4title;

  /// No description provided for @terms5title.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get terms5title;

  /// No description provided for @phoneNumberUpdateInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number starting with \'05\' for updating phone number'**
  String get phoneNumberUpdateInfo;

  /// No description provided for @termsIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Your use of the Application constitutes full and unconditional acceptance of these terms. The Application acts solely as an electronic intermediary platform connecting you with service providers (Technicians).'**
  String get termsIntroduction;

  /// No description provided for @terms1.
  ///
  /// In en, this message translates to:
  /// **'Responsibility for the Request: You are committed to providing an accurate and sufficient description of the issue (text, photo, video) and the service location to enable the Technician to respond.'**
  String get terms1;

  /// No description provided for @terms2.
  ///
  /// In en, this message translates to:
  /// **'Inspection Fees: You are responsible for paying the determined inspection/call-out fees (if applicable) immediately upon the Technician accepting the request and proceeding to the location. These fees are generally non-refundable.'**
  String get terms2;

  /// No description provided for @terms3.
  ///
  /// In en, this message translates to:
  /// **'Payment and Final Cost: The total cost of the service is agreed upon directly with the Technician after inspection, and must be approved via the Application before work commences. You are responsible for paying the agreed-upon amount in full.'**
  String get terms3;

  /// No description provided for @terms4p1.
  ///
  /// In en, this message translates to:
  /// **'Warranty (Guarantee): Completed work is subject to the Platform\'s'**
  String get terms4p1;

  /// No description provided for @warrantyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Warranty Policy'**
  String get warrantyPolicy;

  /// No description provided for @terms4p2.
  ///
  /// In en, this message translates to:
  /// **'the full details of which can be reviewed via the dedicated link.'**
  String get terms4p2;

  /// No description provided for @terms5.
  ///
  /// In en, this message translates to:
  /// **'You have the right to rate the Technician\'s performance after service completion, and you must ensure that ratings are honest and objective.'**
  String get terms5;

  /// No description provided for @policy1.
  ///
  /// In en, this message translates to:
  /// **'Name, phone number, email address, the precise service location address, order history, and Technician ratings.'**
  String get policy1;

  /// No description provided for @policy2.
  ///
  /// In en, this message translates to:
  /// **'Used to match you with Technicians, facilitate the booking and payment process, and send order notifications.'**
  String get policy2;

  /// No description provided for @policy3.
  ///
  /// In en, this message translates to:
  /// **'Your Name, phone number, and location address are shared ONLY with the Technician who accepted your request to enable service delivery.'**
  String get policy3;

  /// No description provided for @pleaseSelectAValid.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid {value}'**
  String pleaseSelectAValid(Object value);

  /// No description provided for @showingResults.
  ///
  /// In en, this message translates to:
  /// **'Showing {count} results. Type to search'**
  String showingResults(Object count);

  /// No description provided for @typeProvinceNameToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type province name to search...'**
  String get typeProvinceNameToSearch;

  /// No description provided for @typeCityNameToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type city name to search...'**
  String get typeCityNameToSearch;

  /// No description provided for @typeNeighborhoodNameToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type neighborhood name to search...'**
  String get typeNeighborhoodNameToSearch;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Trusted, pro technicians. Get service with a tap!'**
  String get loginDescription;

  /// No description provided for @categoriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the main category (Electrician/Plumber) to begin your service request.'**
  String get categoriesDescription;

  /// No description provided for @welcomeToAboGlumbo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Abo Glumbo!'**
  String get welcomeToAboGlumbo;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'We have become your new partner for your peace of mind. We are ready to maintain your home. Start now by requesting your first service.'**
  String get welcomeDescription;

  /// No description provided for @newServiceRequest.
  ///
  /// In en, this message translates to:
  /// **'New Service Request'**
  String get newServiceRequest;

  /// No description provided for @uploadPaymentProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Payment Proof'**
  String get uploadPaymentProof;

  /// No description provided for @paymentProofFiles.
  ///
  /// In en, this message translates to:
  /// **'Payment Proof Files'**
  String get paymentProofFiles;

  /// No description provided for @pleaseSelectAtLeastOneFile.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one file'**
  String get pleaseSelectAtLeastOneFile;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @paymentProofUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Payment proof uploaded successfully'**
  String get paymentProofUploadedSuccessfully;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// No description provided for @addMoreFiles.
  ///
  /// In en, this message translates to:
  /// **'Add More Files'**
  String get addMoreFiles;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @uploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Proof'**
  String get uploadProof;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
