const express = require('express');
const {pool} = require("../db");
const router = express.Router();

async function getPostAndRecent(slug = null) {
    try {
        // Call the stored procedure
        const query = 'SELECT * FROM get_post_with_related_and_recent($1)';
        const result = await pool.query(query, [slug]);

        if (result.rows.length === 0) {
            throw new Error('Post not found');
        }
        const { post, recentposts: recentPosts, relatedposts: relatedPosts } = result.rows[0];
        return { post, recentPosts, relatedPosts };
    } catch (err) {
        console.error('Error fetching post and related data:', err);
        throw err;
    }
}

router.get('/', async (req, res) => {
    try {
        const { post, recentPosts, relatedPosts } = await getPostAndRecent();
        res.render('blogPost', { ...post, recentPosts, relatedPosts });
    } catch (err) {
        console.error('Error fetching latest post or recent posts:', err);
        res.status(err.message === 'Post not found' ? 404 : 500).send(err.message);
    }
});

router.get('/post/:slug', async (req, res) => {
    try {
        const { slug } = req.params;
        const { post, recentPosts, relatedPosts } = await getPostAndRecent(slug);
        res.render('blogPost', { ...post, recentPosts, relatedPosts });
    } catch (err) {
        console.error('Error fetching post or related posts:', err);
        res.status(err.message === 'Post not found' ? 404 : 500).send(err.message);
    }
});

module.exports = router;