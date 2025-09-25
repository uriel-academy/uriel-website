import { Router } from 'express';
import { SearchController } from '../controllers/searchController';

export function setSearchRoutes(router: Router) {
    const searchController = new SearchController();

    router.get('/search', searchController.searchQuestions.bind(searchController));
}