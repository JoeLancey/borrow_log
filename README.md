# BorrowLog

BorrowLog manages university laboratory equipment reservations, physical asset
release and return tracking, notifications, reports, and staff inventory.

## Stack

- Flutter and Dart
- Supabase Auth and Postgres
- Material 3 with Google Fonts
- `fl_chart` for reporting
- `pdf`, `printing`, and `csv` for exports

## Configuration

Supabase configuration is supplied at runtime and is not stored in Dart source.
Use the publishable client key only; never pass a service-role key to Flutter.

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

The same values are required for `flutter build` commands. Store local values
in a private script or IDE launch configuration rather than committing them.

## Supabase setup

The repository currently contains Edge Functions and Supabase configuration,
but does not yet contain the database schema migrations or RLS policy SQL.
Before connecting a new project, create the required tables and policies for
profiles, laboratories, equipment, reservations, returns, and notifications.
Deploy Edge Functions with these server-side secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `BREVO_API_KEY`
- `BREVO_SENDER_EMAIL`
- `BREVO_SENDER_NAME`

## Development

```powershell
flutter pub get
flutter analyze
flutter test
```

## Platforms

The Flutter project includes Android, iOS, web, Windows, macOS, and Linux
targets. Validate printing, CSV delivery, deep links, and password recovery on
each platform before release.

## Asset

The University of Mindanao logo is loaded from
`assets/images/um-logo.png` and declared in `pubspec.yaml`.
