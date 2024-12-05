const express = require('express');
const { pool } = require('../db');
const router = express.Router();

router.get('/', async (req, res) => {
    try {
        const postsQuery = `
            SELECT bp.id, bp.title, bp.slug, bp.created_at, ARRAY_AGG(t.name) AS tags
            FROM blog_posts bp
            LEFT JOIN post_tags pt ON bp.id = pt.post_id
            LEFT JOIN tags t ON pt.tag_id = t.id
            GROUP BY bp.id
            ORDER BY bp.created_at DESC
        `;
        const postsResult = await pool.query(postsQuery);
        const posts = postsResult.rows;

        const groupedPosts = {};
        posts.forEach((post) => {
            const date = new Date(post.created_at);
            const year = date.getFullYear();
            const month = date.toLocaleString('default', { month: 'long' });

            if (!groupedPosts[year]) groupedPosts[year] = {};
            if (!groupedPosts[year][month]) groupedPosts[year][month] = [];

            groupedPosts[year][month].push({
                day: date.getDate(),
                title: post.title,
                slug: post.slug,
                tags: post.tags.filter(Boolean),
            });
        });

        res.render('blogs', { groupedPosts });
    } catch (err) {
        console.error('Error fetching blog posts:', err);
        res.status(500).send('Server error');
    }
});

module.exports = router;
