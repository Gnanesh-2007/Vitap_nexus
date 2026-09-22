# VIT-AP Nexus 🚀

[![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://python.org)
[![Rust](https://img.shields.io/badge/Rust-Native_FFI-DEA584?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod_2.0-2563EB)](https://riverpod.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **VIT-AP Nexus** is a next-generation mobile client and asynchronous microservice ecosystem for VIT-AP University students. It replaces slow, desktop-bound legacy portals with a high-performance, offline-capable mobile experience delivering instant data access, predictive attendance tracking, digital courseware, and automated gate-pass management.

---

## 🌟 Why VIT-AP Nexus?

Legacy university portals often suffer from server timeouts, session expirations, and heavy desktop tables that are difficult to navigate on mobile devices. 

**VIT-AP Nexus solves this through:**
- **0ms Instant Load Times:** Multi-tier Stale-While-Revalidate caching renders your latest data in RAM/Disk instantly before background revalidation.
- **Native Parsing Engine:** High-performance Rust DOM parser (`lib_vtop`) parses complex tabular data locally with zero garbage collection overhead.
- **Offline Reliability:** View your timetable, attendance records, exam schedules, and grades even when the campus network is offline.
- **Modern Editorial UI:** Tailored layout built with modern typography, smooth micro-interactions, and accessible high-contrast design.

---

## ⚡ Core Features

### 1. 📊 Smart Attendance & Predictive Bunk Intelligence
- **Real-Time Eligibility Tracking:** Color-coded status indicators for 75% minimum eligibility and 85% scholarship targets.
- **Mathematical Bunk Calculator:** Automatically computes the exact number of classes you can safely bunk without falling below minimum thresholds, or how many consecutive classes you must attend to recover.
- **Day-Wise Session Logs:** Deep-dive timeline view displaying every slot, date, faculty, and present/absent mark per registered course.

### 2. 📅 Interactive Timetable & Exam Schedule
- **Weekly Schedule View:** Day-by-day timetable showing classroom venues, slot timings, and course codes.
- **Upcoming Class Countdown:** Live indicator highlighting current and next classes for the day.
- **Exam Schedule & Seating:** Comprehensive CAT-1, CAT-2, and FAT exam dates with venue details.

### 3. 📚 Digital Courseware & Resource Hub
- **Direct Material Access:** View syllabus documents, course plans, lecture topics, and faculty reference notes.
- **Lecture-Wise Organization:** Browse lecture notes structured session by session with direct download support.

### 4. 🏡 Hostel Outing Management & Digital Gate Pass
- **Streamlined Leave Booking:** Apply for General or Weekend Outings with automatic time slot configuration.
- **Live Status Tracking:** Real-time lifecycle visibility (*Applied $\rightarrow$ Waiting for Approval $\rightarrow$ Approved / Denied*).
- **Digital Gate Pass:** Automatically generates an authentic vector A4 pass with verifiable cryptographic QR code for seamless security turnstile clearance.

### 5. 🎓 Grade History & Academic Analytics
- **CGPA & Credit Summary:** Real-time calculation of overall CGPA, earned credits, and semester-by-semester GPA trends.
- **Detailed Grade Cards:** Tabular grade breakdown categorized across regular, elective, and audit courses.

### 6. 💳 Fee Ledger & Payment Summary
- **Transaction Overview:** Instant status summary of all academic, hostel, and semester tuition payments with verified timestamps.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Client Layer (Flutter Mobile)               │
│                                                             │
│   • Editorial Design System    • Riverpod State Management  │
│   • 0ms Stale-While-Revalidate • Rust FFI Native Engine     │
│   • Offline Encrypted Storage  • Vector PDF Gate-Pass Gen   │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS / JSON
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Microservice Layer (FastAPI)                │
│                                                             │
│   • Non-Blocking Async I/O     • Dynamic Session Cookie Pool│
│   • Automatic Captcha Handling • Resilient Request Retries  │
│   • API Facade & CORS Normalization                         │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              University Infrastructure (VTOP ERP)           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Technology Stack

| Layer | Technologies |
| :--- | :--- |
| **Mobile Frontend** | Flutter, Dart 3, Riverpod 2.6, Dio, Google Fonts |
| **Native Performance Core** | Rust (`lib_vtop`), `dart:ffi` C-interop bindings |
| **Backend API Gateway** | Python 3.11+, FastAPI, Uvicorn, AsyncIO, Pydantic |
| **State & Storage** | Riverpod, Flutter Secure Storage (AES-256), SharedPreferences |
| **Document Generation** | Vector PDF Engine (`pdf`, `printing`), Dynamic QR Code Generators |
| **Deployment & CI** | Docker, Render Cloud Hosting, GitHub Actions |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK:** `>= 3.12.0` ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Python:** `>= 3.11` ([Install Python](https://www.python.org/downloads/))
- **Git**

---

### 1. Backend Microservice Setup

```bash
# Clone the repository
git clone https://github.com/Gnanesh-2007/Vitap_nexus.git
cd Vitap_nexus

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: .\venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Launch FastAPI development server
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```
The interactive API documentation will be available at `http://localhost:8000/docs`.

---

### 2. Flutter Mobile App Setup

```bash
# Navigate to the Flutter app directory
cd app

# Fetch package dependencies
flutter pub get

# Run on an attached device or emulator
flutter run
```

---

## 🔒 Security & Privacy Architecture

- **Zero Remote Password Storage:** Student credentials are never persisted on cloud databases. Passwords are sent solely over encrypted HTTPS transport to negotiate authenticated session cookies.
- **Device-Level Encryption:** Authentication tokens and biometric keys are saved via `flutter_secure_storage` leveraging the Android Keystore and iOS Keychain.
- **Graceful Error Translation:** Technical network traces and server socket exceptions are filtered through a centralized `ErrorFormatter` to prevent data leakage and provide clear guidance to students.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for full details.