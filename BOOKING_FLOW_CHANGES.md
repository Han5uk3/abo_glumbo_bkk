# Booking Flow Changes - Implementation Plan

## Overview

Modify the booking flow to require payment (service fee) BEFORE booking confirmation, and change the post-completion payment action to upload payment proof.

## Current Flow

1. Select date & time
2. Add issue description, media, and address
3. Select technician
4. **Complete Booking** → Creates booking with status 'P' (Pending), paymentModeCode 'U' (Unpaid)
5. After job completion → "Complete Payment" button shows payment sheet (Telr/Cash)

## New Flow

1. Select date & time
2. Add issue description, media, and address
3. Select technician
4. **NEW: Pay Service Fee** → Card (Telr) or Cash payment
5. **Complete Booking** → Creates booking with payment info
   - If card payment successful → paymentCompleted = true, status = 'P'
   - If cash selected → paymentCompleted = false, status = 'P', paymentModeCode = 'H' (Cash in Hand)
6. After job completion → "Upload Payment Proof" button (replaces payment sheet)
   - Upload file (image/document)
   - Enter paid amount
   - Save to completionData or separate field

## Files to Modify

### Customer App (abo-glumbo-bbk)

#### 1. `lib/sheets/book_service.dart`

- Add `isFourthStep` boolean state
- Add Step 4: Payment selection UI
- Modify `_buildThirdStepBottom()` to navigate to Step 4 instead of creating booking
- Add `_buildFourthStepContent()` - Payment selection (Card/Cash)
- Add `_buildFourthStepBottom()` - Process payment and create booking
- Pass payment info to `CreateBookingEvent`

#### 2. `lib/services/booking/bloc/booking_event.dart`

- Add payment fields to `CreateBookingEvent`:
  - `String paymentMethod` ('card' or 'cash')
  - `bool paymentCompleted`
  - `String? orderId` (for card payments)
  - `String paymentModeCode`

#### 3. `lib/services/booking/bloc/booking_bloc.dart`

- Update `CreateBookingEvent` handler to pass payment info to `addBooking`

#### 4. `lib/services/booking/add_booking.dart.dart`

- Add payment parameters to `addBooking` method
- Set `paymentCompleted`, `paymentModeCode`, `orderId` based on payment method
- If card payment: paymentCompleted = true, paymentModeCode = 'C'
- If cash payment: paymentCompleted = false, paymentModeCode = 'H'

#### 5. `lib/models/booking.dart`

- Add `paymentProof` field (List<String> for file URLs)
- Add `paidAmount` field (double)
- Update `toJson()` and `fromMap()` methods

#### 6. `lib/common_widgets/service_booking_tile.dart`

- Modify `_buildPaymentButton()` to show "Upload Payment Proof" dialog instead of payment sheet
- Create `_showUploadPaymentProofDialog()` method
  - File picker for images/documents
  - Amount input field
  - Upload to Firebase Storage
  - Update booking document

#### 7. Create new file: `lib/sheets/upload_payment_proof_sheet.dart`

- Bottom sheet for uploading payment proof
- File picker (image/document)
- Amount input
- Upload to Firebase Storage
- Update booking with proof URLs and amount

### Technician App (abo-glumbo-panel-bbk)

- **NO CHANGES REQUIRED** - Verify existing complete work flow remains unchanged

## Database Schema Changes

### Booking Document

```json
{
  "paymentCompleted": true/false,
  "paymentModeCode": "C" (Card) | "H" (Cash) | "U" (Unpaid),
  "orderId": "telr_order_id" (for card payments),
  "paymentCompletedAt": Timestamp,
  "paymentProof": ["url1", "url2"], // NEW: Payment proof files
  "paidAmount": 50.0 // NEW: Amount paid for completion
}
```

## Payment Mode Codes

- **C**: Card (Telr)
- **H**: Cash in Hand
- **U**: Unpaid (legacy, should not be used in new flow)

## Implementation Steps

### Phase 1: Add Payment Step to Booking Flow

1. ✅ Modify `book_service.dart` to add Step 4
2. ✅ Update booking events and bloc
3. ✅ Update `addBooking` method with payment params
4. ✅ Test booking creation with card payment
5. ✅ Test booking creation with cash payment

### Phase 2: Change Complete Payment Action

1. ✅ Create `upload_payment_proof_sheet.dart`
2. ✅ Modify `service_booking_tile.dart` payment button
3. ✅ Add fields to booking model
4. ✅ Test file upload and amount saving

### Phase 3: Testing

1. ✅ Test complete booking flow with card payment
2. ✅ Test complete booking flow with cash payment
3. ✅ Test upload payment proof after job completion
4. ✅ Verify technician app is unaffected
5. ✅ Test edge cases (payment failures, network issues)

## Notes

- Use existing Telr integration from `lib/sheets/payment.dart`
- Reuse payment UI components where possible
- Ensure backward compatibility with existing bookings
- Add proper error handling for payment failures
- Show appropriate success/failure messages
