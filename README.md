# SmartInterestX

A loan and interest management app built with **Flutter** and **Firebase**.
Record money you lend or borrow, and the app calculates simple interest, tracks payments, reminds you before due dates and shows analytics.

> SmartInterestX is a record-keeping notebook. It does not connect to a bank and no money moves through it.

Built as a major project for **Unlox Academy**.

## Features

- **Contacts**: borrowers and lenders, with search and filters
- **Loans**: Given (you lent) or Taken (you borrowed), monthly or yearly rate, start and due dates, notes, live interest preview
- **Interest engine**: simple interest, interest till today and till the due date, payments cover interest first, then principal
- **Payments**: partial or full settlement, payment mode, proof photo, edit and delete
- **Reminders**: notifications 1, 3 or 7 days before the due date, on the due date, and when overdue
- **Analytics**: receivables, payables, interest earned and paid, Given vs Taken chart, monthly interest flow
- **Export and backup**: CSV and Excel export, backup file, restore, automatic cloud storage
- **Security**: Firebase login, private data per user, app PIN, optional biometric lock, auto-lock

## Tech stack

| Layer | Technology |
|---|---|
| App | Flutter (Dart) |
| State management | Provider |
| Authentication | Firebase Authentication (email and password) |
| Database | Cloud Firestore |
| Notifications | flutter_local_notifications |
| Export and sharing | excel, share_plus, path_provider, file_picker |
| App lock | shared_preferences, crypto, local_auth |

## How interest is calculated

```
Interest = Principal x (Rate / 100) x Time
```

- **Monthly rate**: whole calendar months count fully, leftover days count as days / 30
- **Yearly rate**: whole years count fully, leftover days count as days / 360
- Each payment first covers the accrued interest, and the rest reduces the principal
- Balance = outstanding principal + unpaid interest

Example: Rs 50,000 at 1% per month from 01 Jul 2026 has Rs 1,500 interest on 01 Oct 2026 (3 months).

## Project structure

```
lib/
  models/      Contact, Loan, Payment
  providers/   LedgerProvider (data, balances, Firestore), SecurityProvider (PIN lock)
  services/    AuthService, NotificationService, ExportService
  screens/     All app screens
  widgets/     Reusable UI parts
  utils/       Interest calculator, formatters, colours
```

## Run it yourself

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and Android Studio.
2. Clone the repository and get the packages:

   ```bash
   git clone https://github.com/YOUR_USERNAME/SmartInterestX.git
   cd SmartInterestX
   flutter pub get
   ```

3. Connect your own Firebase project:
   - Create a project at the [Firebase console](https://console.firebase.google.com)
   - Turn on **Authentication** with the Email/Password method
   - Create a **Cloud Firestore** database and publish these rules:

     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{userId}/{document=**} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
         }
       }
     }
     ```

   - Run `flutterfire configure` to create your own `lib/firebase_options.dart` and `android/app/google-services.json`
4. Run the app:

   ```bash
   flutter run
   ```

Android build settings used: NDK 27, minSdk 24, Kotlin 2.4.0, core library desugaring.

## Limitations

- Loans are not shared between two accounts. Each person records the loan in their own ledger.
- Only simple interest with one fixed rate per loan
- Proof photos are stored compressed inside Firestore (Firebase Storage needs a paid plan)
- Tested on Android only

## Author

Aye Myint, B.Tech Information Technology, Parul University