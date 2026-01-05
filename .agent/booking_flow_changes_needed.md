# Booking Flow Changes - Area Validation Update

## Current Flow (book_service.dart)

Step 1: Date + Time Selection
Step 2: Location Selection (map picker) + Issue Media + Notes
Step 3: Payment

## New Flow Required

Step 1: **Address Selection** + Date + Time

- Select from saved addresses dropdown
- Real-time area validation
- Show error if address not serviceable
- Prevent navigation if invalid

Step 2: Issue Media + Notes

- Upload images
- Add description

Step 3: Payment (unchanged)

## Key Changes Needed in book_service.dart

### 1. State Variables

```dart
// Add these
AddressModel? selectedAddress;
String? addressValidationError;
bool isValidatingAddress = false;

// Remove location-related variables from step 2
```

### 2. Step 1 UI Changes

Move address selection to step 1 (currently in step 2)

- Add address dropdown at top of step 1
- Show validation status below address selector
- Display error message in red if not serviceable

### 3. Area Validation Logic

```dart
Future<void> _validateSelectedAddress() async {
  if (selectedAddress == null || selectedTechnician == null) return;

  setState(() => isValidatingAddress = true);

  try {
    final isServiceable = await LocationMatcherService.isAddressInServiceArea(
      customerLat: selectedAddress!.lat!,
      customerLon: selectedAddress!.lon!,
      technicianServiceAreas: selectedTechnician!.serviceAreas,
    );

    setState(() {
      addressValidationError = isServiceable
        ? null
        : "Service not available in this area";
      isValidatingAddress = false;
    });
  } catch (e) {
    debugPrint("Error validating address: $e");
    setState(() {
      addressValidationError = "Failed to validate service area";
      isValidatingAddress = false;
    });
  }
}
```

### 4. Navigation Logic

Update "Next" button in step 1:

```dart
// Only allow navigation if:
// 1. Address is selected
// 2. Address is validated
// 3. No validation error
// 4. Date and time selected

if (selectedAddress == null) {
  // Show error
  return;
}

if (addressValidationError != null) {
  // Show error - cannot proceed
  return;
}

// Proceed to step 2
```

### 5. Remove from Step 2

- Location map picker
- All location-related UI
- Keep only: Issue media upload + notes

## Files to Modify

1. **book_service.dart** - Main booking flow
2. **add_image_booking.dart** - If it handles step 2 separately
3. **save_booking.dart** - Update to use selectedAddressId instead of location

## Testing Checklist

- [ ] Address dropdown shows all saved addresses
- [ ] Validation runs when address selected
- [ ] Error shows in red when not serviceable
- [ ] Cannot proceed with invalid address
- [ ] Can proceed with valid address
- [ ] Step 2 only shows media + notes
- [ ] Booking saves with addressId reference
