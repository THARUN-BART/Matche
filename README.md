# 💫 Matche

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Render-46E3B7?style=for-the-badge&logo=render&logoColor=white" alt="Render">
</div>

<div align="center">
  <h3>🚀 A Dynamic Peer-Connection and Chat Platform</h3>
  <p>Built with Flutter • Real-time Messaging • Profile Matching • Group Creation</p>
</div>

## 📖 About Matche

Matche is a modern, feature-rich social platform that connects people through intelligent profile matching and seamless communication. Built entirely with Flutter, it offers a native experience across multiple platforms while maintaining a robust backend infrastructure deployed on Render.

## � Key Highlights

- **Cross-Platform**: Works on Android, iOS, and Web
- **Real-Time Communication**: Instant messaging with live updates
- **Smart Matching**: Algorithm-based profile matching system
- **Group Dynamics**: Create and manage interest-based groups
- **Cloud-Ready**: Scalable backend architecture

## ✨ Features

### 🔐 Authentication System
- Secure user registration and login
- Profile creation and customization
- Email verification and password recovery

### 💬 Real-Time Messaging
- Peer-to-peer chat functionality
- Group messaging capabilities
- Message delivery status indicators
- Typing indicators and read receipts

### 🎯 Smart Matching
- AI-powered profile matching algorithm
- Interest-based compatibility scoring
- Location-aware matching (optional)
- Advanced filtering options

### 👥 Group Management
- Create public and private groups
- Role-based group administration
- Group discovery and recommendations
- File and media sharing

### 🎨 User Experience
- Clean, intuitive interface design
- Dark theme support
- Responsive design for all screen sizes
- Smooth animations and transitions

## 📱 Download & Installation

### 📲 APK Download
Ready to try Matche? Download the latest APK:

[📦 Download MATCHE APK](https://drive.google.com/file/d/1MiXVosHu-ZmFj6hNm4ylmFVYjV2CdbGZ/view?usp=drive_link)

- Minimum Android Version: 5.0 (API level 21)
- File Size: ~25MB

## 🔧 Developer Setup

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=2.17.0)
- Android Studio / VS Code
- Git

### 1. Clone the Repository
```bash
git clone https://github.com/THARUN-BART/Matche.git
cd Matche/matcha-cp
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Verify Flutter Setup
```bash
flutter doctor
```

### 4. Run the Application
```bash
# Run on connected device
flutter run

# Run on specific platform
flutter run -d chrome          # Web
flutter run -d android         # Android
flutter run -d ios             # iOS (macOS only)
```

## 🏗️ Project Architecture

```
matcha-cp/
├── 📁 lib/
│   ├── 🔐 Authentication/          # User auth logic & screens
│   ├── 🎨 constants/               # App-wide constants
│   ├── 📱 screen/                  # Main app screens
│   ├── 🔧 service/                 # API & business logic
│   ├── � widget/                  # Reusable components
│   ├── 🚀 main.dart               # App entry point
│   └── ✨ splash_screen.dart      # Initial loading screen
├── 📄 pubspec.yaml                # Dependencies & assets
├── 🔧 android/                    # Android-specific files
├── 🍎 ios/                       # iOS-specific files
└── 🌐 web/                       # Web-specific files
```

## 🌐 Backend Infrastructure

### API Endpoint
```
https://backend-u5oi.onrender.com
```

### 🔗 Backend Repository
The complete backend source code is available at: [Matche Backend Repository](#)

### ⚡ Performance Notes
- Backend hosted on Render's free tier
- First request after inactivity may take 30-60 seconds (cold start)
- Push notifications may experience delays during cold starts
- For production use, consider upgrading to paid hosting

## 🛠️ Configuration

### Firebase Setup
1. Create a new Firebase project
2. Enable Authentication, Firestore, and Cloud Messaging
3. Download google-services.json (Android) and GoogleService-Info.plist (iOS)
4. Place files in respective platform directories

### Environment Variables
Create a .env file in the root directory:

```env
API_BASE_URL=https://backend-u5oi.onrender.com
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

## 🧪 Testing

### Run Tests
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget/
```

## 🚀 Deployment

### Android APK Build
```bash
flutter build apk --release
```

### iOS Build
```bash
flutter build ios --release
```

### Web Build
```bash
flutter build web --release
```

## 🐛 Troubleshooting

### Common Issues

#### Dependencies Issues
```bash
flutter pub cache repair
flutter clean
flutter pub get
```

#### Build Issues
```bash
cd android && ./gradlew clean && cd ..
flutter clean
flutter build apk
```

#### Backend Connection Issues
- Verify API endpoint URL
- Check internet connectivity
- Wait for cold start (30-60 seconds)

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### 🔧 Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write/update tests
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### 📝 Contribution Guidelines
- Follow Flutter/Dart style guidelines
- Write clear commit messages
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting

### 🐞 Reporting Bugs
Found a bug? Please create an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)
- Device/platform information

## 📊 Roadmap

### 🎯 Upcoming Features
- Voice messaging
- Video calling
- Story sharing
- Advanced matching filters
- Multi-language support
- Push notification improvements

## 🔄 Version History
- v1.0.0 - Initial release with core features
- v0.9.0 - Beta release with group functionality
- v0.8.0 - Alpha release with basic chat

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](#) file for details.

## 📞 Support & Contact

### 📧 Get in Touch
- Developer: THARUN-BART
- Email: tharunpoongavanam@gmail.com
- GitHub: @THARUN-BART
## 👨‍💻 Contributors

| Name           | GitHub Profile                                      | Contributions                                      |
|----------------|-----------------------------------------------------|----------------------------------------------------|
| Tharun         | [@THARUN-BART](https://github.com/THARUN-BART)      | Project Owner, Fullstack                           |
| Ugesh Praveed  | [@Ugesh-Praavin](https://github.com/Ugesh-Praavin)  | UI Design, Docs, Worked in some places             |
| Jyoshinisri    | [@jyoshinisris](https://github.com/jyoshinisris)    | UI Design, Docs, PPT, Explanation & Idea of Project|



### 💬 Community
- Report issues: [GitHub Issues](#)
- Feature requests: [GitHub Discussions](#)

## 🙏 Acknowledgments
- Flutter team for the amazing framework
- Firebase for backend services
- Render for hosting infrastructure
- Open source community for inspiration

<div align="center">
  <p>Made with ❤️ by THARUN-BART</p>
  <p>⭐ Star this repo if you found it helpful!</p>
</div>
