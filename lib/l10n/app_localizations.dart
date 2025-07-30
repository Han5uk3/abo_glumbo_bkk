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

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @profileManagement.
  ///
  /// In en, this message translates to:
  /// **'Profile Management'**
  String get profileManagement;

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

  /// No description provided for @failedToLoadServices.
  ///
  /// In en, this message translates to:
  /// **'Failed to load services'**
  String get failedToLoadServices;

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

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

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

  /// No description provided for @cityName.
  ///
  /// In en, this message translates to:
  /// **'City Name'**
  String get cityName;

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
  /// **'Create account'**
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

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

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

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

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

  /// No description provided for @areYouSureToWantCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to want cancel booking?'**
  String get areYouSureToWantCancelBooking;

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
  /// **'Sign up later'**
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

  /// No description provided for @cashOnHands.
  ///
  /// In en, this message translates to:
  /// **'Payment in cash'**
  String get cashOnHands;

  /// No description provided for @processingPayment.
  ///
  /// In en, this message translates to:
  /// **'Processing Payment'**
  String get processingPayment;

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
  /// **'Cash Payment Pending'**
  String get paymentPending;

  /// No description provided for @paymentPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your booking is confirmed. Please pay the worker in cash at the time of service.'**
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

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

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

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

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
  /// **'Payment pending. Please pay when the worker completes the work.'**
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
  /// **'Biometric Authentication'**
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

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

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

  /// No description provided for @trackWorker.
  ///
  /// In en, this message translates to:
  /// **'Track Worker'**
  String get trackWorker;

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

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;
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
