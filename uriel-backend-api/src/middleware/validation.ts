import { Request, Response, NextFunction } from 'express';

export const validateQuestion = (req: Request, res: Response, next: NextFunction) => {
    const { subject, year, content } = req.body;

    if (!subject || typeof subject !== 'string') {
        return res.status(400).json({ error: 'Subject is required and must be a string.' });
    }

    if (!year || typeof year !== 'number') {
        return res.status(400).json({ error: 'Year is required and must be a number.' });
    }

    if (!content || typeof content !== 'string') {
        return res.status(400).json({ error: 'Content is required and must be a string.' });
    }

    next();
};

export const validateSearch = (req: Request, res: Response, next: NextFunction) => {
    const { keyword, subject, year } = req.query;

    if (keyword && typeof keyword !== 'string') {
        return res.status(400).json({ error: 'Keyword must be a string.' });
    }

    if (subject && typeof subject !== 'string') {
        return res.status(400).json({ error: 'Subject must be a string.' });
    }

    if (year && typeof year !== 'string') {
        return res.status(400).json({ error: 'Year must be a string.' });
    }

    next();
};