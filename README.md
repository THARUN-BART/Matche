# 💫 Matche  

**Matche** is a dynamic peer-connection and chat platform built with **Flutter**. It features profile matching, group creation, and real-time messaging. The backend is deployed via [Render](https://render.com) for seamless cloud integration.

---

## 🚀 Getting Started

### 1. 🔧 Clone the Repository

```bash
git clone https://github.com/THARUN-BART/Matche.git
cd Matche
cd matcha-cp
```

> Replace `THARUN-BART` with your actual GitHub username.

---

### 2. 📦 Install Dependencies

```bash
flutter pub get
```

Make sure Flutter SDK is properly installed:

```bash
flutter doctor
```

---

### 3. 🧪 Run the App

To run on a device or web:

```bash
flutter run
```

To specify a platform:

```bash
flutter run -d chrome    # Web  
flutter run -d emulator  # Android Emulator
```

---

### 4. 🌐 Backend Deployment

The backend is hosted on **Render**.

🔗 **API Endpoint**

```
https://backend-u5oi.onrender.com
```

Update this URL wherever API calls are made inside the Flutter project.

---

---

## 📁 Project Structure

```
matcha-cp/
├── lib/
│ ├── Authentication/ # Sign in / Sign up / Auth logic
│ ├── constants/ # App-wide constants (colors, text, etc.)
│ ├── screen/ # App UI screens
│ ├── service/ # API calls and business logic
│ ├── widget/ # Reusable UI components
│ ├── firebase_options.dart # Firebase initialization config
│ ├── main.dart # App entry point
│ └── splash_screen.dart # Initial splash screen
├── pubspec.yaml # Project dependencies and assets
└── README.md # Project documentation
```

---

## ✅ Features

- 🗨️ Peer-to-peer chat  
- 🔍 Profile matching  
- 👥 Group creation & interaction  
- 🌐 Backend REST APIs via Render  
- 🎨 Clean and responsive UI

---

## 📌 Notes

- If dependencies cause issues:

```bash
flutter pub cache repair
```

- ⚠️ Push notifications & matching screen may not work instantly due to Render’s free tier cold start delay.
Although your backend is live, responses may take time after inactivity.

---

## 🔗 Backend Algorithm Repository

> The backend logic (matching, chat, etc.) is open-source!

📦 **Backend GitHub Repo**:  
[https://github.com/THARUN-BART/backend](https://github.com/your-username/matche-backend)

> Replace `THARUN-BART` with your actual GitHub username.

---

## ❤️ Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

---

## 📫 Contact

Feel free to reach out if you have questions or want to collaborate!
