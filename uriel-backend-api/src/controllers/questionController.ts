import { Request, Response } from 'express';
import { QuestionService } from '../services/questionService';

export class QuestionController {
    private questionService: QuestionService;

    constructor() {
        this.questionService = new QuestionService();
    }

    public async createQuestion(req: Request, res: Response): Promise<void> {
        try {
            const questionData = req.body;
            const newQuestion = await this.questionService.createQuestion(questionData);
            res.status(201).json(newQuestion);
        } catch (error) {
            res.status(500).json({ message: 'Error creating question', error });
        }
    }

    public async getQuestions(req: Request, res: Response): Promise<void> {
        try {
            const questions = await this.questionService.getQuestions();
            res.status(200).json(questions);
        } catch (error) {
            res.status(500).json({ message: 'Error retrieving questions', error });
        }
    }

    public async getQuestionById(req: Request, res: Response): Promise<void> {
        try {
            const questionId = req.params.id;
            const question = await this.questionService.getQuestionById(questionId);
            if (question) {
                res.status(200).json(question);
            } else {
                res.status(404).json({ message: 'Question not found' });
            }
        } catch (error) {
            res.status(500).json({ message: 'Error retrieving question', error });
        }
    }

    public async updateQuestion(req: Request, res: Response): Promise<void> {
        try {
            const questionId = req.params.id;
            const updatedData = req.body;
            const updatedQuestion = await this.questionService.updateQuestion(questionId, updatedData);
            if (updatedQuestion) {
                res.status(200).json(updatedQuestion);
            } else {
                res.status(404).json({ message: 'Question not found' });
            }
        } catch (error) {
            res.status(500).json({ message: 'Error updating question', error });
        }
    }

    public async deleteQuestion(req: Request, res: Response): Promise<void> {
        try {
            const questionId = req.params.id;
            const deleted = await this.questionService.deleteQuestion(questionId);
            if (deleted) {
                res.status(204).send();
            } else {
                res.status(404).json({ message: 'Question not found' });
            }
        } catch (error) {
            res.status(500).json({ message: 'Error deleting question', error });
        }
    }
}