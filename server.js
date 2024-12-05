//server.js 
const express = require('express');
const { pool } = require('./db');
const path = require('path');
const exphbs = require('express-handlebars');

const app = express();

// Configure Handlebars
const hbs = exphbs.create({
    extname: '.handlebars',
    layoutsDir: path.join(__dirname, 'views/layouts'),
    defaultLayout: 'main',
    partialsDir: path.join(__dirname, 'views/partials'),
    helpers: {
        prefixPartial: (type) => `content-${type}`, // Helper to add "content-" prefix
    },
});
app.engine('.handlebars', hbs.engine);
app.set('view engine', '.handlebars');
app.set('views', path.join(__dirname, 'views'));

// Middleware to parse JSON and static files
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.use('/', require('./routes/post')); //including home / and /posts/:slug
app.use('/posts', require('./routes/posts'));
app.use('/search', require('./routes/search'));
app.use('/images', require('./routes/images'));


async function startServer() {
    app.listen(3000, () => {
        console.log('Server running on http://localhost:3000');
    });
}

startServer();
