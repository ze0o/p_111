# Car Insurance App

A Flutter application for managing vehicle insurance from registration through
policy approval, payment, and claims. The app uses Firebase Authentication,
Cloud Firestore, Firebase Storage, and Firebase Cloud Messaging.

The application is designed around two roles. Customers manage their vehicles
and insurance lifecycle from one mobile interface. Administrators review
requests and accident reports from a separate dashboard. Authentication state
and the Firestore user role determine which experience is displayed after login.

## Features

### Customers

- Create an account and sign in securely
- Register vehicles with vehicle details and images
- Search and filter registered vehicles
- Request insurance for a vehicle
- View insurance policies and policy status
- Complete insurance payments
- Submit accident reports with supporting images
- Receive insurance and account notifications

### Administrators

- View dashboard and insurance activity
- Review, approve, and reject insurance requests
- Manage insurance policies
- Review accident reports and update their status
- View application analytics
- Create additional administrator accounts

## Typical Workflows

### Customer workflow

1. Register with an email address and password.
2. Add a vehicle and provide its identifying information.
3. Submit an insurance request for the vehicle.
4. Track the request and view an approved policy.
5. Complete payment when required by the policy flow.
6. Submit an accident report with the accident date, description, damaged parts,
   repair cost, and required evidence.

### Administrator workflow

1. Sign in with an account whose `users/{userId}.role` is `Admin`.
2. Review pending insurance requests from the admin dashboard.
3. Approve or reject requests and manage resulting policy records.
4. Review accident reports and update their status.
5. Use dashboard analytics to monitor insurance activity.

## Technology

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging and local notifications
- `image_picker` for vehicle and accident images

## Requirements

- Flutter SDK compatible with Dart `3.8.0` or later
- Android Studio and an Android emulator/device, or Xcode and an iOS simulator/device
- A Firebase project with Authentication, Firestore, Storage, and Cloud Messaging enabled

The current source contains a Firebase web configuration in `lib/main.dart`.
Treat that configuration as environment-specific application configuration and
replace it when deploying to a different Firebase project. Do not commit server
credentials, service-account files, or private signing keys.

## Getting Started

1. Clone the repository and open it in VS Code or Android Studio.
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Configure Firebase for the platforms you intend to run. The Firebase project
   used by this code is `itcs444-proj`; use your own Firebase project for a
   separate deployment and replace the platform configuration accordingly.
4. Enable the following Firebase services:
   - Email/password Authentication
   - Cloud Firestore
   - Firebase Storage
   - Firebase Cloud Messaging
5. Add the platform-specific Firebase files required by the target platform
   when using a different Firebase project. Configure Android and Apple
   notification settings before enabling push notifications there.
6. Confirm that the Firestore security rules allow authenticated users to read
   and write only the records they are authorized to access. Admin access should
   be restricted to users whose `role` is `Admin`.
7. Run the application:

   ```bash
   flutter run
   ```

## Firebase Data Model

The app currently uses these Firestore collections:

- `users` - account details and the user `role` (`Admin` or customer)
- `users/{userId}/tokens` - device tokens for notifications
- `users/{userId}/notifications` - in-app notification records
- `vehicles` - registered vehicle information
- `insurance_requests` - customer insurance requests and review status
- `insurance_policies` - approved policy records
- `accident_reports` - customer-submitted accident reports

The initial route is selected from Firebase Authentication state. Authenticated
users with the `Admin` role are sent to the admin dashboard; other authenticated
users are sent to the customer home page.

Customer-owned documents should be protected by the authenticated user ID in
Firestore rules. Role checks in the client improve navigation, but authorization
must also be enforced by backend rules.

## Notifications

Notification permissions are requested at startup. Device tokens are saved to
Firestore and users are subscribed to role-based and user-specific topics.

Before enabling push notifications in a deployment, configure the server-side
FCM credentials and platform notification settings. The notification service
currently contains a placeholder for the FCM server key and should not be used
with that placeholder in production.

The accident-report screen currently requires an image in its form but stores a
placeholder image URL instead of uploading the selected image. Complete the
Firebase Storage upload flow before using accident evidence in production.

## Project Structure

```text
lib/
  main.dart                         App entry point and authentication routing
  login_page.dart                   Customer/admin sign-in
  register_page.dart                Customer registration
  home_page.dart                    Customer vehicle dashboard
  vehicle_registration_page.dart    Add a vehicle
  insurance_request_page.dart       Request insurance
  insurance_policy_page.dart        View policies
  payment_page.dart                 Pay for insurance
  accident_report_page.dart         Submit an accident report
  admin_home_page.dart              Admin dashboard
  admin_insurance_management.dart   Review insurance requests and policies
  admin_accident_reports_page.dart  Review accident reports
  services/                         Shared services such as notifications
  theme/                            Application theme
  widgets/                          Reusable UI components
```

## Platform Notes

- The app locks the interface to portrait orientation at startup.
- Camera/gallery access requires the appropriate Android and iOS permissions.
- Firebase Messaging permissions are requested when the app starts.
- The default Android release configuration uses the debug signing key and is
   suitable for local testing only. Configure a release keystore before shipping.
- Android, iOS, macOS, Linux, Windows, and web runner folders are included, but
   Firebase and notification behavior should be verified for each target.

## Known Development Limitations

- Push delivery needs a secure server-side FCM implementation; the client-side
   placeholder key is not a production configuration.
- Accident images are not yet uploaded to Firebase Storage.
- Firestore security rules are not included in this repository and must be
   supplied as part of deployment configuration.

## Useful Commands

```bash
flutter analyze
flutter test
flutter build apk
```

## License

No license has been specified for this project.
