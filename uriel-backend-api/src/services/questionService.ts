import { Question } from '../models/Question';

export class QuestionService {
    private questions: Question[] = [];

    constructor() {
        // Initialize with some dummy data
        this.questions = [
            new Question(1, 'Math', 2023, 'What is 2 + 2?'),
            new Question(2, 'Science', 2022, 'What is the chemical formula for water?'),
            new Question(3, 'History', 2021, 'Who was the first president of the United States?'),
        ];
    }

    public getQuestions(): Question[] {
        return this.questions;
    }

    public getQuestionById(id: number): Question | undefined {
        return this.questions.find(question => question.id === id);
    }

    public createQuestion(subject: string, year: number, content: string): Question {
        const newQuestion = new Question(this.questions.length + 1, subject, year, content);
        this.questions.push(newQuestion);
        return newQuestion;
    }

    public updateQuestion(id: number, subject: string, year: number, content: string): Question | undefined {
        const questionIndex = this.questions.findIndex(question => question.id === id);
        if (questionIndex !== -1) {
            this.questions[questionIndex] = new Question(id, subject, year, content);
            return this.questions[questionIndex];
        }
        return undefined;
    }

    public deleteQuestion(id: number): boolean {
        const questionIndex = this.questions.findIndex(question => question.id === id);
        if (questionIndex !== -1) {
            this.questions.splice(questionIndex, 1);
            return true;
        }
        return false;
    }
}