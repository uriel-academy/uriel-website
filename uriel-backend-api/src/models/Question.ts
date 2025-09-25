export class Question {
    id: number;
    subject: string;
    year: number;
    content: string;

    constructor(id: number, subject: string, year: number, content: string) {
        this.id = id;
        this.subject = subject;
        this.year = year;
        this.content = content;
    }
}