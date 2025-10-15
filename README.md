# CashFlowX

[![Flutter](https://img.shields.io/badge/Framework-Flutter-blue)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-orange)](https://firebase.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow)]()

> **CashFlowX** is a modern personal finance mobile app built with **Flutter**, designed to simplify the way users track and manage their money.  
> It offers a clean, intuitive, and visually appealing interface for logging transactions, organizing accounts, setting budgets, and monitoring your financial progress.

---

## Key Features

- 💰 **Transactions Management** — Add, edit, and delete incomes, expenses, or transfers with full control.
- 🏦 **Multiple Accounts** — Handle personal, business, savings, or credit card accounts.
- 🌍 **Multi-Currency Support** — Convert between global currencies in real-time.
- 📆 **Smart Views** — Analyze your balance by week, month, year, or calendar.
- 🔁 **Recurring Transactions** — Automate salary, bills, or subscriptions.
- 🎯 **Budgets & Goals** — Set financial goals and track your spending habits.
- 🌙 **Dark Mode** — Fully optimized for light and dark themes.
- 🌐 **Multi-Language** — English & Spanish supported.
- 📶 **Offline Mode** — Works fully offline using **SQLite**, with optional **Firebase sync**.

---

## Tech Stack

| Layer | Technology |
|-------|-------------|
| **Framework** | Flutter 3.x |
| **Language** | Dart |
| **State Management** | Provider |
| **Database** | SQLite |
| **Backend / Cloud Sync** | Firebase |
| **Localization** | easy_localization |
| **External APIs** | Currency conversion APIs |
| **Architecture** | Clean Architecture + MVVM Pattern |

---

## App Preview

| Dashboard | Calendar | Accounts |
|------------|-----------|----------|
| ![Dashboard](assets/screenshots/dashboard.png) | ![Calendar](assets/screenshots/calendar.png) | ![Accounts](assets/screenshots/accounts.png) |

| Add Transaction | Edit Transaction | Recurring Transactions |
|------------------|------------------|-------------------------|
| ![Add Transaction](assets/screenshots/add_transaction.png) | ![Edit Transaction](assets/screenshots/edit_transaction.png) | ![Recurring](assets/screenshots/recurring.png) |

| Settings | Currency Selector | Account Detail |
|-----------|------------------|----------------|
| ![Settings](assets/screenshots/settings.png) | ![Currency](assets/screenshots/currency.png) | ![Account](assets/screenshots/account_detail.png) |

> *All screenshots taken from the iOS simulator during active development.*

---

## Project Structure

```
lib/
├── models/              # Core data models (Transaction, Account, Category)
├── screens/             # Main UI screens (Home, Calendar, Settings, etc.)
├── widgets/             # Reusable Flutter widgets
├── providers/           # State management using Provider
├── utils/               # Formatters, constants, and helpers
└── main.dart            # Entry point
```

---

## Installation & Setup

### Requirements
- Flutter SDK 3.x+
- Dart >= 3.0
- Android Studio or VS Code
- Emulator or physical device

### Steps

```bash
# Clone the repository
git clone https://github.com/agnerdiaz/CashFlowX.git

# Enter the project folder
cd CashFlowX

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## Project Objective

CashFlowX was built to create a **simple yet powerful financial manager** that adapts to the lifestyle of young professionals.  
The mission is to promote healthy financial habits through design, usability, and technology — turning complex money management into something effortless and enjoyable.

---

## Project Status

**In active development**  
**Beta version** — currently being finalized for Play Store & App Store release.  

### Upcoming Features
- Export reports to **CSV / PDF**
- **Smart notifications** for budget alerts
- **Multi-device synchronization**
- **Advanced analytics dashboard**

---

## 👤 Developer

**Agner David Díaz Encarnación**  
Software Engineering Student | Flutter Developer  
📍 San Cristóbal, Dominican Republic  

- 💼 [LinkedIn](https://www.linkedin.com/in/agnerdiaz)  
- 💻 [GitHub](https://github.com/agner)  
- ✉️ agnerdiazenc@gmail.com  

---

## License

This project is licensed under the **MIT License**.  
© 2025 Agner David Díaz Encarnación.

---

> *"CashFlowX was designed to transform how people understand and manage their money — combining simplicity, design, and power in one seamless experience."*
