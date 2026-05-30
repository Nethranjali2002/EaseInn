# Frontend Agent Directives: Flutter & Dart (EnergyoSense)

## 1. Core Operating Rules (Strict Token Optimization)
* **Code-Only Output:** Output strictly the requested Dart code, `pubspec.yaml` configurations, or bash commands.
* **Zero Exposition:** Exclude greetings, conversational filler, summaries, and concluding remarks.
* **Diff Updates:** For existing files, return only the modified widgets, classes, or lines. Do not print the entire unchanged file.
* **Explicit Explanations:** Provide explanations, architectural justifications, or widget tree breakdowns **ONLY** if the user appends the `--explain` flag.

## 2. Technical Context & Environment
* **Assumed Expertise:** Expert Flutter Developer and DevSecOps Engineer.
* **Core Stack:** Flutter, Dart, RESTful APIs (Node.js/Express backend).
* **Architecture:** Feature-driven directory structure (e.g., `lib/features/`, `lib/core/`).
* **State Management & Networking:** Utilize Riverpod for state management and Dio for robust HTTP requests.
* **CI/CD Automation:** Align build processes with lightweight webhook deployment strategies. Avoid heavy mobile orchestration overhead.

## 3. Frontend Coding Standards
* **Modern Dart Syntax:** Utilize null safety, late variables, pattern matching, and sealed classes effectively.
* **Component Reusability:** Extract repetitive UI elements into modular, stateless widgets.
* **Centralized API Handling:** Manage all backend communication through a dedicated networking layer. Never embed raw HTTP calls directly inside UI widgets.
* **Error Handling:** Implement centralized exception catching and user-friendly error boundaries mirroring the backend's standardized JSON responses.

## 4. DevSecOps & Security Baselines
* **Secure Token Storage:** Always use `flutter_secure_storage` for managing JWTs and sensitive session data. Never use `shared_preferences` for secrets.
* **API Protection:** Implement Dio interceptors to automatically inject Authorization headers and handle 401 token refresh logic seamlessly.
* **Data Sanitization:** Validate and sanitize all user inputs on the client side before transmitting payloads to the Node.js backend.
* **Release Security:** Configure release builds with code obfuscation (`--obfuscate --split-debug-info`) and disable logging in production environments.

## 5. Formatting Standards
* Provide production-ready, flawlessly formatted Dart code ready for direct insertion into Android Studio or VS Code.
* Omit standard inline comments unless documenting complex state lifecycles, cryptographic implementations, or non-standard security configurations.

## 6. Dynamic Scope & Feature Management
* **Proactive Feature Tracking:** If a new frontend requirement is explicitly requested, or if a standard necessary feature (e.g., offline caching, pagination, or secure routing) is logically required to support the backend architecture, immediately flag it.
* **Checklist Updates:** Output the exact modified line or markdown task (e.g., `- [ ] Implement Dio interceptor for JWT refresh`) required to update the `checklists.md` file without asking for permission, strictly adhering to the Code-Only Output rule.