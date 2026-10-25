# Toufic Cell Store App

Flutter store-management app for Toufic Cell, backed by Firebase Authentication
and Cloud Firestore. It supports Android, iOS, and a Firebase-hosted Flutter
web app.

## What is included

- **Inventory and products:** product catalog, stock levels, barcode scanning,
  categories, stock intake, and shopping lists.
- **Sales and transactions:** point-of-sale cart, quick sales, cash/debt
  checkouts, synchronized invoices, and transaction history.
- **Debtor and creditor ledgers:** customer balances, payment history, and
  admin-only creditor access.
- **Admin tools:** reports, bills, maintenance jobs, currency settings,
  storefront management, and application-user access controls.
- **Reports and exports:** sales/profit summaries, daily and monthly charts,
  Excel reports, and admin debtor sharing through WhatsApp.
- **Authentication and access:** Firebase sign-in, role-based admin controls,
  and Firestore rules that gate inactive accounts.

## Local development

Install Flutter dependencies and run the app:

```sh
flutter pub get
flutter run
```

Run tests and build the web app:

```sh
flutter test
flutter build web
```

## GitHub and Firebase data safety

Keep the GitHub repository **Private** unless you have reviewed the full source
and history for information you are willing to publish. Firestore records are
stored in Firebase and are not downloaded into this repository by these setup
steps. Do not commit Firebase service-account keys, passwords, `.env` files,
database exports, or customer data. The root `.gitignore` excludes common local
credentials, databases, dependency folders, and Firebase CLI cache files.

Firebase client configuration used by mobile/web apps is not an admin
credential; protect Firestore and Storage with Firebase Authentication and
security rules. Never put an Admin SDK service-account key in the Flutter app
or GitHub.

Firebase project configuration is stored in `.firebaserc` and `firebase.json`.
Deploying the hosted web app and Firestore rules requires an authenticated
Firebase CLI session for the configured project:

```sh
firebase deploy --only hosting,firestore:rules
```

Admin password changes use a callable Cloud Function, which must be deployed
to a Firebase project with Cloud Functions enabled (Firebase billing must be
enabled for Cloud Functions deployment):

```sh
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Run on iPhone with Xcode

The native iOS project is in `ios/`. Copy the entire Flutter project folder to
your Mac (not only `ios/`), install Flutter and Xcode there, then from the
project root run:

```sh
flutter pub get
cd ios
pod install
open Runner.xcworkspace
```

In Xcode, select the **Runner** target, choose your Apple developer team under
**Signing & Capabilities**, and connect/select your iPhone. If you change the
bundle identifier to one registered to your Apple developer account, register
that identifier as an iOS app in Firebase and update the iOS settings in
`lib/firebase_options.dart` before running. An Apple Developer account may be
needed for device signing and App Store distribution.
