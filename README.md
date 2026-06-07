# EaseInn Property Management System (PMS)

EaseInn is a comprehensive, multi-platform Property Management System designed for hotels, resorts, and vacation rentals. It features a robust Node.js backend architecture and dynamic cross-platform Flutter applications (Web Admin Portal & Mobile App). 

Built with scalability and intelligence in mind, EaseInn empowers property managers to streamline operations, optimize revenue through AI, and elevate the guest experience across multiple properties.

---

## 🌟 Key Features

### 🏢 Multi-Property Management
- Seamlessly manage multiple properties, resorts, or apartment complexes from a single dashboard.
- Create and organize rooms in bulk with automated sequential code generation (e.g., `RM-0001`).
- Centralized or per-property data filtering.

### 🤖 AI-Powered Revenue Intelligence
- **Dynamic Demand Forecasting:** Visual charts analyzing historical booking data to project future occupancy and revenue.
- **Intelligent Pricing Suggestions:** AI-driven rate recommendations based on real-time occupancy, seasonal trends, and weekend/weekday demand.
- **Confidence Scoring:** Real-time confidence metrics to ensure data-backed decision-making.

### 📅 Bookings & Task Management
- Real-time booking engine with status tracking (Pending, Confirmed, Checked-in, Checked-out, Cancelled).
- Automated check-in/check-out tracking and capacity management.
- Granular task assignment system for staff (Maintenance, Cleaning, Support) with real-time completion tracking.

### 🔐 Advanced Role-Based Access Control (RBAC)
- **Admin:** Full system access, consolidated analytics, cross-property management, and AI intelligence tools.
- **Manager:** Complete operational access for assigned properties (Rooms, Bookings, Tasks, Payments).
- **Staff:** Restricted view focused solely on assigned tasks and operational execution.
- Secure Dual-Token Authentication (Access & Refresh tokens).

### 📊 Comprehensive Analytics & Exports
- Consolidated Dashboard giving a 360-degree view of portfolio health (Revenue, Occupancy, Task Completion).
- Beautiful, interactive charts powered by Flutter's `fl_chart`.
- One-click **PDF and CSV Exports** for Bookings, Payments, Rooms, and Tasks.

### 🖼️ Enhanced Profile & Media Handling
- Robust local or cloud-based file upload systems for Room Galleries, Property Covers, and User Profile Avatars.
- Automated path resolution and safe blob/buffer handling optimized for both Flutter Web and Mobile platforms.

---

## 🏗️ System Architecture

EaseInn utilizes a modern monorepo-style structure separated into dedicated functional directories:

```text
EaseInn/
├── backend/                  # Node.js, Express, MongoDB (Mongoose)
│   ├── src/controllers/      # Business logic (AI, Analytics, Entities)
│   ├── src/models/           # Mongoose schemas
│   ├── src/routes/           # Express REST endpoints
│   └── src/services/         # Database and core operations
├── frontend/                 # Core UI Codebase
│   ├── shared/               # Shared logic, Riverpod providers, API client
│   └── web/                  # Flutter Web App (Admin Portal)
└── easeinn_mobile/           # Flutter Mobile App (Staff / Guest Portal)
```

---

## 🚀 Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) (v16 or higher)
- [MongoDB](https://www.mongodb.com/) (Local instance or Atlas URI)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+ recommended)

### 1. Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure Environment Variables:
   Create a `.env` file in the `backend/` root:
   ```env
   PORT=3000
   MONGODB_URI=mongodb://localhost:27017/easeinn
   JWT_SECRET=your_super_secret_key
   JWT_EXPIRES_IN=1d
   ```
4. Start the Development Server:
   ```bash
   npm run dev
   ```
   *The server will start on `http://localhost:3000`.*

### 2. Frontend Web (Admin Dashboard) Setup

1. Navigate to the web frontend directory:
   ```bash
   cd frontend/web
   ```
2. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application on Chrome:
   ```bash
   flutter run -d chrome
   ```

### 3. Mobile App Setup

1. Navigate to the mobile application directory:
   ```bash
   cd easeinn_mobile
   ```
2. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run on an emulator or connected device:
   ```bash
   flutter run
   ```

---

## 🛠️ Tech Stack

**Backend**
- Node.js & Express.js
- MongoDB & Mongoose
- Multer (File Uploads)
- Swagger (API Documentation)
- PDFKit / json2csv (Data Export)

**Frontend (Web & Mobile)**
- Flutter & Dart
- Riverpod (State Management)
- Dio (API Networking)
- GoRouter (Navigation)
- FL Chart (Data Visualization)

---

## 📝 Recent System Improvements
- Implemented **Self-Healing DB Counters** for sequential code generation (`RM-0001`), preventing collisions during manual DB seeds and bulk creations.
- Deployed a **Consolidated `/dashboard/stats` Endpoint** to aggregate massive portfolio data efficiently without overwhelming the client.
- Revamped the **AI Revenue Optimizer UI**, introducing gradient badge styling, actionable trend analytics, and real-time visual progress indicators.
- Fixed complex **Profile Upload Workflows**, properly securing file payloads and auto-refreshing the Riverpod Auth State on completion.

---

*Built for operational excellence and seamless hospitality.*
