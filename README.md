# BJJ Fitness App

## Overview

The BJJ Fitness App is a cross-platform mobile application designed to help
Brazilian Jiu-Jitsu practitioners track their training, monitor progress,
review techniques, and manage nutrition and recovery information.

This repository contains the Flutter application and platform-specific
files used to develop the mobile application.

## Core Features

Planned and developing features include:

- User accounts and profiles
- Training session logging
- Training history
- Technique library
- Weekly training progress
- Training goal tracking
- Nutrition tracking
- Recovery tracking

## Technology Stack

- Flutter - Cross-platform application framework
- Dart - Primary programming language
- Firebase Authentication - User authentication
- Cloud Firestore - Application data storage
- Firebase Storage - User-uploaded media and profile images
- GitHub - Version control and collaborative development

Additional technologies may be added as development progresses.

## Project Structure

The Flutter project contains platform-specific and shared application files:

- `lib/` - Main Dart application source code
- `android/` - Android platform configuration
- `ios/` - iOS platform configuration
- `web/` - Web platform configuration
- `test/` - Application tests
- `pubspec.yaml` - Flutter dependencies and project configuration

Additional platform folders are generated and maintained by Flutter.

## Development

The application is being developed using Flutter so that shared Dart code
can be used across supported platforms.

Platform-specific code may be added when functionality requires native
Android or iOS implementation.

## Related Repositories

The BJJ Fitness App project is organized across multiple repositories:

- [BJJ Assets](https://github.com/Resmeralda/bjj-fitness-app-assets) - Project documentation, design assets, diagrams, mockups, and sprint reports
- [BJJ Contracts](https://github.com/Resmeralda/bjj-contracts) - Data schemas, interface definitions, and application contracts

## Documentation

Project-wide design documentation, requirements, mockups, and sprint reports
are maintained in the BJJ Assets repository.

Shared data structures and interfaces are documented in the BJJ Contracts
repository.
