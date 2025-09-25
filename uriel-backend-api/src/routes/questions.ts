import { Router } from 'express';
import { QuestionController } from '../controllers/questionController';

const router = Router();
const questionController = new QuestionController();

export function setQuestionRoutes(app: Router) {
  app.post('/questions', questionController.createQuestion.bind(questionController));
  app.get('/questions', questionController.getQuestions.bind(questionController));
  app.get('/questions/:id', questionController.getQuestionById.bind(questionController));
  app.put('/questions/:id', questionController.updateQuestion.bind(questionController));
  app.delete('/questions/:id', questionController.deleteQuestion.bind(questionController));
}