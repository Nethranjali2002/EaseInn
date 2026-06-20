/// ==========================================
/// SHARED PACKAGE - Barrel Export File
/// ==========================================
/// This file is the single entry point for the shared package.
/// Both the web and mobile apps import only this file to access
/// all shared models, providers, API clients, and UI components.
///
/// Instead of importing 20+ individual files, apps just do:
///   import 'package:shared/shared.dart';
///
/// This keeps imports clean and makes it easy to add new shared
/// components without updating every import statement.
/// ==========================================
library shared;

// ==========================================
// CORE - Infrastructure & Utilities
// ==========================================
// API communication
export 'core/api/api_client.dart';       // HTTP client for backend communication
export 'core/api/api_exception.dart';    // Custom error type for API failures
export 'core/api/api_interceptor.dart';  // Auto token refresh on 401 errors

// Secure storage
export 'core/storage/secure_storage.dart'; // Encrypted JWT token persistence

// Theming
export 'core/theme/app_theme.dart';      // App-wide light/dark theme configuration

// Utilities
export 'core/utils/image_utils.dart';    // Image URL resolution helpers

// Reusable widgets
export 'core/widgets/app_button.dart';   // Standardized button component
export 'core/widgets/app_text_field.dart'; // Standardized text input component

// ==========================================
// FEATURES - Business Logic Providers
// ==========================================
// Each provider manages state and API calls for its domain.

// Authentication (login, register, logout, password management)
export 'features/auth/data/auth_provider.dart';

// Property management (CRUD for hotels/resorts)
export 'features/property/data/property_provider.dart';

// Room management (CRUD for rooms within a property)
export 'features/property/data/room_provider.dart';

// Booking management (reservations, check-in/out, cancellations)
export 'features/booking/data/booking_provider.dart';

// Task management (staff assignments, completion tracking)
export 'features/task/data/task_provider.dart';

// User profile management (view/edit profile, account deletion)
export 'features/profile/data/user_provider.dart';

// Dashboard (aggregated stats and metrics)
export 'features/dashboard/data/dashboard_provider.dart';

// Notifications (auto-polling, mark as read)
export 'features/notification/data/notification_provider.dart';
