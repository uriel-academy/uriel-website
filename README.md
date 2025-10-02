# uriel_mainapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running Locally with Docker

You can run both the backend and frontend locally without installing dependencies:

1. Make sure Docker and Docker Compose are installed.
2. In the project root, run:

   ```sh
   docker-compose up --build
   ```

- The backend will be available at http://localhost:3000
- The frontend (web) will be available at http://localhost:8080

Any code changes will be reflected automatically (volumes are mounted).
