const express = require('express');
const path = require('path');
const fs = require('fs');
const router = express.Router();

router.use('/', (req, res) => {
    const filePath = path.join(__dirname, '../images', req.path);
    fs.access(filePath, fs.constants.F_OK, (err) => {
        if (err) {
            res.sendFile(path.join(__dirname, '../images/default.svg'));
        } else {
            res.sendFile(filePath);
        }
    });
});

module.exports = router;
