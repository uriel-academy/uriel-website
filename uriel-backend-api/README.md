# Uriel Backend API

## Overview
The Uriel Backend API is a RESTful API built with TypeScript and Express.js for managing past questions. It provides functionality for creating, retrieving, updating, and deleting questions, as well as searching for questions based on various criteria.

## Project Structure
```
uriel-backend-api
├── src
│   ├── controllers          # Contains controllers for handling requests
│   │   ├── questionController.ts
│   │   └── searchController.ts
│   ├── models               # Defines data models
│   │   ├── Question.ts
│   │   └── Subject.ts
│   ├── routes               # Defines API routes
│   │   ├── questions.ts
│   │   └── search.ts
│   ├── services             # Contains business logic
│   │   ├── questionService.ts
│   │   └── searchService.ts
│   ├── middleware           # Middleware for authentication and validation
│   │   ├── auth.ts
│   │   └── validation.ts
│   ├── config               # Configuration files
│   │   └── database.ts
│   ├── types                # TypeScript types and interfaces
│   │   └── index.ts
│   └── app.ts              # Entry point of the application
├── package.json             # NPM package configuration
├── tsconfig.json            # TypeScript configuration
└── README.md                # Project documentation
```

## Installation
1. Clone the repository:
   ```
   git clone <repository-url>
   ```
2. Navigate to the project root directory:
   ```
   cd uriel-website
   ```
3. Build and start the backend API using Docker:
   ```
   docker-compose up --build backend
   ```

This will automatically install dependencies and start the backend server in a container. No need to run `npm install` locally.

## Usage
1. Start the server:
   ```
   npm start
   ```
2. The API will be available at `http://localhost:3000`.

## API Endpoints
- **Questions**
  - `GET /questions` - Retrieve all questions
  - `POST /questions` - Create a new question
  - `GET /questions/:id` - Retrieve a question by ID
  - `PUT /questions/:id` - Update a question by ID
  - `DELETE /questions/:id` - Delete a question by ID

- **Search**
  - `GET /search` - Search for questions based on keywords, subjects, or years

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## License
This project is licensed under the MIT License.
