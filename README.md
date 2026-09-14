<p align="center">
  <img src="app/assets/images/konoha_logo.png" width="80" alt="VITAP Nexus Logo"/>
</p>

<h1 align="center">VITAP Nexus</h1>

<p align="center">
  <strong>A premium student companion app for VIT-AP University</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white" alt="FastAPI"/>
  <img src="https://img.shields.io/badge/Python-3.13+-3776AB?logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/Deployed_on-Render-46E3B7?logo=render&logoColor=white" alt="Render"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License"/>
</p>

<p align="center">
  <em>Access your VTOP academic data — attendance, marks, timetable, grades, and more — through a beautifully crafted mobile experience.</em>
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔐 **Secure OTP Login** | Two-factor authentication with VIT-AP's VTOP portal |
| 📊 **Dashboard** | Today's schedule, live class countdown, quick stats at a glance |
| 📋 **Attendance** | Course-wise attendance %, safe bunk calculator |
| 📅 **Timetable** | Interactive day-by-day weekly schedule with venue & faculty |
| 📝 **Marks** | CAT-1, CAT-2, FAT breakdown with weighted scores |
| 🎓 **Grades & CGPA** | Semester GPA history, credit tracking, full grade tables |
| 👤 **Profile** | Student info, hostel details, academic information |
| 📚 **Courses** | Course materials, syllabus, lecture notes download |
| 📄 **Assignments** | Digital assignment tracking with deadline management |
| 🚶 **Outings** | General & weekend outing request management |
| 🔬 **Biometrics** | Campus turnstile punch logs |
| 💰 **Payments** | Fee dues and receipt tracking |
| 👨‍🏫 **Mentor** | Faculty mentor/proctor contact details |
| 🌐 **VTOP Portal** | Embedded live VTOP via reverse proxy |

---

## 🏗️ Architecture

```
┌──────────────────────────┐          ┌─────────────────────────┐
│   Flutter Mobile App     │  HTTPS   │   FastAPI Backend        │
│   (app/)                 │ ◄──────► │   (src/)                 │
│                          │          │                          │
│  • Riverpod State Mgmt   │          │  • Auth + OTP Sessions   │
│  • Dio HTTP Client       │          │  • VTOP Data Endpoints   │
│  • Secure Storage        │          │  • Reverse Proxy         │
│  • Cyberpunk Dark Theme  │          │  • API Key Middleware    │
└──────────────────────────┘          └────────────┬────────────┘
                                                   │
                                            ┌──────▼──────┐
                                            │  VIT-AP VTOP │
                                            │  Portal      │
                                            └─────────────┘
```

---

## 📁 Project Structure

```
Vitap_nexus/
├── app/                          # Flutter Mobile Application
│   ├── lib/
│   │   ├── main.dart             # App entry point
│   │   ├── providers/            # Riverpod state management
│   │   │   ├── auth_provider.dart
│   │   │   └── vtop_providers.dart
│   │   ├── screens/              # 16 feature screens
│   │   │   ├── login_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── attendance_screen.dart
│   │   │   ├── timetable_screen.dart
│   │   │   ├── marks_screen.dart
│   │   │   └── ...
│   │   ├── services/             # API client & storage
│   │   ├── theme/                # Cyberpunk dark theme
│   │   ├── utils/                # Helpers & VTOP embed
│   │   └── widgets/              # Reusable UI components
│   ├── assets/images/            # App assets
│   └── pubspec.yaml
│
├── src/                          # FastAPI Backend
│   ├── main.py                   # App initialization & CORS
│   ├── config.py                 # Environment configuration
│   ├── dependencies.py           # API key verification
│   ├── models/
│   │   └── api_models.py         # Pydantic request/response schemas
│   ├── routers/
│   │   ├── auth.py               # Login, OTP verification
│   │   ├── student_data.py       # Academic data endpoints
│   │   └── vtop_proxy.py         # VTOP reverse proxy
│   └── utils/
│       └── handle_client_exception.py
│
├── requirements.txt              # Python dependencies
├── Dockerfile                    # Container build
├── Procfile                      # Render start command
├── render.yaml                   # Render deployment config
├── .env.example                  # Environment variable template
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter** >= 3.12 ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Python** >= 3.13 ([Install Python](https://python.org/downloads/))
- **Git** ([Install Git](https://git-scm.com/))

### 1. Clone the Repository

```bash
git clone https://github.com/Gnanesh-2007/Vitap_nexus.git
cd Vitap_nexus
```

### 2. Backend Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env and set your API_KEY

# Run the server
uvicorn src.main:app --reload --port 8000
```

The API will be available at `http://localhost:8000` with docs at `/docs`.

### 3. Flutter App Setup

```bash
cd app

# Install dependencies
flutter pub get

# Run with your API key
flutter run --dart-define=API_KEY=your-api-key-here
```

> **Note:** Pass your API key via `--dart-define` at build time. Never hardcode secrets!

---

## 🌐 Deployment

### Backend (Render)

The backend is configured for one-click deployment on [Render](https://render.com):

1. Fork this repo
2. Connect your Render account to GitHub
3. Create a new **Web Service** and select this repo
4. Set the environment variable `API_KEY` in the Render dashboard
5. Deploy!

> The `render.yaml` blueprint is included for automatic configuration.

### Flutter App

```bash
# Build APK
flutter build apk --dart-define=API_KEY=your-api-key-here

# Build iOS
flutter build ios --dart-define=API_KEY=your-api-key-here
```

---

## 🔒 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/login` | Initiate login with registration number & password |
| `POST` | `/auth/verify_otp` | Verify OTP for two-factor authentication |
| `POST` | `/auth/resend_otp` | Resend OTP code |
| `GET` | `/student/attendance` | Fetch attendance data |
| `GET` | `/student/timetable` | Fetch class timetable |
| `GET` | `/student/marks` | Fetch exam marks |
| `GET` | `/student/grades` | Fetch grade history |
| `GET` | `/student/profile` | Fetch student profile |
| `GET` | `/student/outings` | Fetch outing requests |
| `GET` | `/student/biometric` | Fetch biometric logs |
| `GET` | `/student/assignments` | Fetch digital assignments |
| `GET` | `/vtop_proxy/start_session` | Start VTOP proxy session |

All endpoints require the `X-API-Key` header for authentication.

---

## 🛠️ Tech Stack

### Frontend
- **Flutter** — Cross-platform UI framework
- **Riverpod** — Reactive state management
- **Dio** — HTTP client with interceptors
- **Flutter Secure Storage** — Encrypted credential storage
- **Flutter Animate** — Smooth micro-interactions

### Backend
- **FastAPI** — High-performance Python web framework
- **vitap-vtop-client** — VTOP portal scraping engine
- **Pydantic** — Data validation & serialization
- **Uvicorn** — ASGI server

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [vitap-vtop-client](https://github.com/Udhay-Adithya/vitap-vtop-client) by Udhay Adithya — The core VTOP scraping library
- VIT-AP University — For the academic ecosystem

---

<p align="center">
  Built with ❤️ for VIT-AP students
</p>