const express = require('express');
const { pool } = require('../db');
const router = express.Router();

router.get('/', async (req, res) => {
    try {
        const { q, limit } = req.query;
        if (!q) {
            return res.status(400).send('Query parameter "q" is required.');
        }
        const searchQuery = 'SELECT * FROM search_blog_posts($1, $2)';
        const result = await pool.query(searchQuery, [q, limit ? parseInt(limit, 10) : null]);
        res.render('searchResults', { query: q, posts: result.rows });
    } catch (err) {
        console.error('Error executing search:', err);
        res.status(500).send('Server error');
    }
});

module.exports = router;
