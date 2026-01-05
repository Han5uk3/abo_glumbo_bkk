# Area Validation System - Implementation Plan

## Overview

Major update to implement radius-based area validation system with auto-location fetching and saved addresses.

## Key Parameters

- **Service Radius**: 2,500 meters (2.5 km) - Based on Saudi district sizes
- **Geocoding Strategy**: Primary method with JSON coordinates as fallback
- **Location Update**: Auto-fetch on registration (create) and login (update)

## Completed Steps

### ✅ 1. Core Services & Models

- [x] Created `LocationMatcherService` with 2.5km radius validation
- [x] Updated `hierarchical_location.dart` - Added coordinates to District model
- [x] Added `SelectedCity` model for technician service areas
- [x] Updated `AddressModel` - Added `isCurrentLocation` flag
- [x] Copied `saudi_hierarchical.json` to customer app

## Pending Implementation

### 2. Customer App - Registration Flow

**File**: `lib/pages/SignUp/signup_page.dart`

**Changes**:

- Remove all location dropdown fields (Province, City, District)
- Auto-fetch current location using `LocationServices`
- Create initial "Current Location" address with `isCurrentLocation: true`
- Store in customer's `addresses` array
- Remove `detailedLocation` field usage

**New signup() logic**:

```dart
1. Validate name & email only
2. Fetch current GPS coordinates
3. Reverse geocode to get address name
4. Create AddressModel with:
   - id: UUID
   - fullName: Reverse geocoded address
   - lat/lon: GPS coordinates
   - isCurrentLocation: true
   - phoneNumber: From Firebase Auth
   - buildingNumber: "N/A" (placeholder)
5. Create CustomerModel with addresses: [currentLocationAddress]
6. Save to Firestore
```

### 3. Customer App - Login Flow

**File**: `lib/services/auth_services.dart` -> `checkUser()`

**Changes**:

- After successful login (userDoc.exists), fetch current location
- Find existing address with `isCurrentLocation: true`
- If found: Update coordinates and name
- If not found: Create new current location address
- Update customer document

**Implementation**:

```dart
if (userDoc.exists) {
  await LocalStoreHelper.putUID(uid);

  // Fetch and update current location
  await _updateCurrentLocationAddress(uid);

  await NotificationServices.refreshFCMToken();
  // Navigate to home...
}
```

### 4. Customer App - Edit Profile

**File**: `lib/pages/profile/edit_profile.dart`

**Changes**:

- Remove location selection fields completely
- Keep only: Name, Email, Phone update
- Location management happens through saved addresses

### 5. Customer App - Booking Flow Reorder

**Files**:

- `lib/sheets/book_service.dart`
- `lib/sheets/add_image_booking.dart` (if exists)

**New Flow**:

```
Step 1: Service Location + Date + Time Slot
  - Select from saved addresses dropdown
  - Real-time service availability validation
  - Show error in red if address not serviceable
  - Prevent "Next" button if invalid

Step 2: Issue Media + Notes
  - Upload images
  - Add description
  - Complete booking
```

**Validation Logic**:

```dart
onAddressSelected(AddressModel address) async {
  final isServiceable = await LocationMatcherService.isAddressInServiceArea(
    customerLat: address.lat!,
    customerLon: address.lon!,
    technicianServiceAreas: selectedTechnician.serviceAreas,
  );

  setState(() {
    selectedAddress = address;
    addressValidationError = isServiceable
      ? null
      : "Service not available in this area";
  });
}
```

### 6. Technician App - Registration

**File**: `abo-glumbo-panel-bbk/lib/pages/auth/signup_page.dart` (or equivalent)

**Changes**:

- Remove manual location selection
- Auto-fetch GPS location during registration
- Store coordinates in technician profile
- Service area selection remains separate (uses hierarchical selector)

### 7. Technician App - Service Area Selection

**File**: Already implemented in `hierarchical_location_selector.dart`

**Verify**:

- Uses `saudi_hierarchical.json`
- Stores as `List<SelectedCity>`
- Has "Select All" for cities and provinces
- ✅ Already working correctly

### 8. User Model Updates

**Customer Model** (`lib/models/customer.dart`):

- Keep `detailedLocation` for backward compatibility (deprecated)
- Remove from new registrations
- Primary location source: `addresses` array

**Technician/User Model** (`abo-glumbo-panel-bbk/lib/models/user.dart`):

- Add `serviceAreas` field: `List<SelectedCity>`
- Add current location coordinates: `lat`, `lon`
- Remove old location dependencies

### 9. Booking Model Updates

**Both apps**: `lib/models/booking.dart`

**Add**:

- `selectedAddressId`: String (reference to customer's saved address)
- Keep existing location fields for backward compatibility

### 10. Worker List Filtering

**File**: `lib/pages/categories/worker_list.dart` (customer app)

**Update**:

- Filter technicians based on selected address
- Use `LocationMatcherService.isAddressInServiceArea()`
- Show only technicians who service the selected area

## Testing Checklist

### Customer Flow

- [ ] New registration creates current location address
- [ ] Login updates current location address
- [ ] Can add/edit/delete saved addresses
- [ ] Booking shows address selection first
- [ ] Service availability validation works
- [ ] Error message displays for non-serviceable areas
- [ ] Cannot proceed with invalid address

### Technician Flow

- [ ] Registration auto-fetches location
- [ ] Service area selection works (hierarchical)
- [ ] Select all provinces/cities functions
- [ ] Service areas saved correctly

### Area Validation

- [ ] 2.5km radius matching works
- [ ] Geocoding primary, JSON fallback works
- [ ] Distance calculation accurate
- [ ] Edge cases handled (no coordinates, etc.)

## Migration Notes

### Existing Users

- Keep old `detailedLocation` data intact
- On next login, create/update current location address
- Gradually migrate to new system

### Existing Bookings

- Leave as-is (backward compatibility)
- New bookings use `selectedAddressId`

## Files Modified Summary

### Customer App (abo-glumbo-bbk)

1. ✅ `lib/services/location_matcher_service.dart` - NEW
2. ✅ `lib/models/hierarchical_location.dart` - UPDATED
3. ✅ `lib/models/address.dart` - UPDATED
4. ⏳ `lib/pages/SignUp/signup_page.dart` - MAJOR UPDATE
5. ⏳ `lib/services/auth_services.dart` - UPDATE
6. ⏳ `lib/pages/profile/edit_profile.dart` - UPDATE
7. ⏳ `lib/sheets/book_service.dart` - MAJOR UPDATE
8. ⏳ `lib/pages/categories/worker_list.dart` - UPDATE
9. ⏳ `lib/models/booking.dart` - UPDATE

### Technician App (abo-glumbo-panel-bbk)

1. ⏳ `lib/pages/auth/signup_page.dart` - UPDATE
2. ✅ `lib/common_widget/hierarchical_location_selector.dart` - VERIFY
3. ⏳ `lib/models/user.dart` - UPDATE
4. ⏳ `lib/models/booking.dart` - UPDATE

## Dependencies to Add

### Customer App pubspec.yaml

```yaml
dependencies:
  geolocator: ^latest
  geocoding: ^latest
  uuid: ^latest # For generating address IDs
```

## Next Steps

1. Update customer registration (remove location, add auto-fetch)
2. Update login flow (update current location)
3. Update edit profile (remove location)
4. Reorder booking flow
5. Add address validation
6. Update technician registration
7. Test end-to-end
