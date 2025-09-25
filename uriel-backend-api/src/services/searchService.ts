import { Question } from '../models/Question';

export class SearchService {
    private questions: Question[];

    constructor(questions: Question[]) {
        this.questions = questions;
    }

    searchQuestions(keyword: string, subject?: string, year?: number): Question[] {
        return this.questions.filter(question => {
            const matchesKeyword = question.content.toLowerCase().includes(keyword.toLowerCase());
            const matchesSubject = subject ? question.subject.toLowerCase() === subject.toLowerCase() : true;
            const matchesYear = year ? question.year === year : true;

            return matchesKeyword && matchesSubject && matchesYear;
        });
    }
}