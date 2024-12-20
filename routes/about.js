const express = require('express');
const router = express.Router();

router.get('/', async (req, res) => {
    try {
        res.render('about');
    } catch (err) {
        console.error('Error fetching blog posts:', err);
        res.status(500).send('Server error');
    }
});

module.exports = router;
