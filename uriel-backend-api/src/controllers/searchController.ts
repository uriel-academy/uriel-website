import { Request, Response } from 'express';
import { SearchService } from '../services/searchService';

export class SearchController {
    private searchService: SearchService;

    constructor() {
        this.searchService = new SearchService();
    }

    public async searchQuestions(req: Request, res: Response): Promise<void> {
        const { keyword, subject, year } = req.query;

        try {
            const results = await this.searchService.searchQuestions(keyword as string, subject as string, year as string);
            res.status(200).json(results);
        } catch (error) {
            res.status(500).json({ message: 'Error searching questions', error: error.message });
        }
    }
}