import express from 'express';
import { json } from 'body-parser';
import { setQuestionRoutes } from './routes/questions';
import { setSearchRoutes } from './routes/search';
import { connectToDatabase } from './config/database';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(json());

// Connect to the database
connectToDatabase();

// Routes
setQuestionRoutes(app);
setSearchRoutes(app);

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});