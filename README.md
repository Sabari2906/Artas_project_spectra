# 🏥 Artas Clinic Management System

## Project Summary

Artas is a full-stack clinic management web application built specifically for specialized medical centers such as hair transplant clinics. The system allows clinic administrators to manage the complete patient lifecycle — from registering new patients and scheduling appointments, to tracking treatment history, managing surgical inventory, recording lab results, and handling prescriptions. The web dashboard provides a clean and modern interface where staff can view patient profiles, monitor appointment statuses (Pending, Confirmed, Completed, Cancelled), manage inventory stock levels with low-stock alerts, and utilize an integrated AI assistant powered by Google Gemini for answering clinic-related queries. All data is securely stored in a relational MySQL database, and the backend automatically creates and seeds the required tables on first run.

---

## Technical Specifications

Languages Used:

Dart → Frontend
JavaScript (Node.js+ Express) → Backend
SQL (MySQL) → Database layer
Google Gemini API → Integrated AI assistant chatbot

---

## Project Structure

```
Artas_web/
├── frontend/          # Flutter web application (Dart)
│   ├── lib/           # All Dart source code & screens
│   ├── assets/        # Images and static assets
│   └── pubspec.yaml   # Flutter dependencies
│
├── server/            # Node.js Express backend
│   ├── index.js       # Main server entry point & all API routes
│   ├── database.js    # MySQL connection pool & table initialization
│   ├── public/        # Admin web dashboard (HTML)
│   ├── uploads/       # Uploaded patient files
│   ├── .env           # Environment variables (DB credentials, port)
│   └── package.json   # Node.js dependencies
│
└── README.md
```

---

## How to Run the Project

### Prerequisites

Make sure the following are installed on your machine before starting:

- [Node.js](https://nodejs.org/) (v18 or above)
- [Flutter SDK](https://flutter.dev/) (v3.x or above)
- [MySQL Server](https://www.mysql.com/) (running locally on port `3306`)
- [Google Chrome](https://www.google.com/chrome/) (for the Flutter web app)

---

### Step 1 — Configure Environment Variables

A template file `server/.env.example` is provided. Copy it and rename it to `.env`, then fill in your own credentials:

```bash
# In the server/ directory:
copy .env.example .env
```

Then open `server/.env` and replace the placeholder values with your own:

```env
PORT=5000
MYSQL_URI="mysql://YOUR_DB_USERNAME:YOUR_DB_PASSWORD@localhost:3306/clinic"
```

> ⚠️ Never share your `.env` file or commit it to GitHub. It contains your database password.

> Make sure the `clinic` database exists in MySQL. You can create it with:
> ```sql
> CREATE DATABASE clinic;
> ```
> The server will automatically create all required tables on first run.

---

### Step 2 — Start the Backend Server

Open a terminal, navigate to the `server/` directory, and run:

```bash
cd server
npm install
node index.js
```

The backend API will start on **`http://localhost:5000`**. You should see a "Connected to MySQL" confirmation in the terminal.

---

### Step 3 — Start the Frontend (Flutter Web App)

Open a **new** terminal, navigate to the `frontend/` directory, and run:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

This will compile the Flutter app and launch it directly in your Google Chrome browser.

---

### Step 4 — Access the Admin Dashboard (Optional)

The HTML admin dashboard is served by the backend. Once the server is running, open your browser and go to:

```
http://localhost:5000
```

---

## Key Features

- 👤 **Patient Management** — Register, view, and update patient records
- 📅 **Appointment Scheduling** — Book, confirm, and track appointments by status
- 🧪 **Lab Results** — Upload and manage patient lab reports
- 💊 **Prescriptions** — Create and export prescriptions as PDF
- 📦 **Inventory Management** — Track surgical accessories with low-stock alerts
- 🤖 **AI Assistant** — Gemini-powered chatbot for clinic queries
- 🌗 **Light/Dark Mode** — Toggle between themes in the Flutter UI
