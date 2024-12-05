CREATE TABLE IF NOT EXISTS blog_posts (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    byline TEXT NOT NULL,
    hero_image TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    sections JSONB NOT NULL,
    slug TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS post_tags (
    post_id INT NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
    tag_id INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);


CREATE OR REPLACE FUNCTION create_blog_post(
    title TEXT,
    subtitle TEXT,
    byline TEXT,
    hero_image TEXT,
    slug_param TEXT,
    sections JSONB,
    tags JSONB,
    created_ts TIMESTAMP DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
new_post_id INTEGER;
    final_slug TEXT;
    provided_created_ts TIMESTAMP := COALESCE(created_ts, NOW());
    tag_name TEXT;
    tag_id INTEGER;
    slug_conflict BOOLEAN;
BEGIN
    -- Generate slug if not provided
    IF slug_param IS NULL THEN
        final_slug := regexp_replace(lower(title), '[^a-z0-9]+', '-', 'g');
ELSE
        final_slug := slug_param;
END IF;

    -- Check for slug conflict and resolve
SELECT EXISTS (SELECT 1 FROM blog_posts WHERE slug = final_slug) INTO slug_conflict;

IF slug_conflict THEN
        final_slug := final_slug || '-' || to_char(provided_created_ts, 'YYYY_MM_DD');
END IF;

    -- Insert the new post into blog_posts
INSERT INTO blog_posts (title, subtitle, byline, hero_image, slug, sections, created_at)
VALUES (title, subtitle, byline, hero_image, final_slug, sections, provided_created_ts)
    RETURNING id INTO new_post_id;

-- Loop through each tag in the JSON array
FOR tag_name IN SELECT jsonb_array_elements_text(tags) LOOP
                       -- Check if the tag already exists, insert it if not
                    INSERT INTO tags (name)
                VALUES (tag_name)
                ON CONFLICT (name) DO NOTHING
                    RETURNING id INTO tag_id;

-- Get the tag ID if it already exists
IF tag_id IS NULL THEN
SELECT id INTO tag_id FROM tags WHERE name = tag_name;
END IF;

        -- Bind the post to the tag
INSERT INTO post_tags (post_id, tag_id)
VALUES (new_post_id, tag_id);
END LOOP;

    -- Return the new post ID
RETURN new_post_id;
END;
$$ LANGUAGE plpgsql;

   
CREATE OR REPLACE FUNCTION get_post_with_related_and_recent(slug_param TEXT)
RETURNS TABLE(
    post JSONB,
    recentPosts JSONB,
    relatedPosts JSONB
) AS $$
BEGIN
    -- Fetch the main post based on slug_param or the latest post if slug_param is NULL
RETURN QUERY
    WITH main_post AS (
        SELECT 
            row_to_json(bp.*)::JSONB AS post_data, -- Cast row_to_json to JSONB
            bp.id AS post_id
        FROM blog_posts bp
        WHERE bp.slug = slug_param OR slug_param IS NULL
        ORDER BY bp.created_at DESC
        LIMIT 1
    ),
    recent_posts_cte AS (
        SELECT jsonb_agg(jsonb_build_object('title', title, 'slug', slug, 'created_at', created_at)) AS recent_posts_data
        FROM (
            SELECT bp.title, bp.slug, bp.created_at
            FROM blog_posts bp
            CROSS JOIN main_post
            WHERE bp.id != main_post.post_id
            ORDER BY bp.created_at DESC
            LIMIT 10
        ) AS recent
    ),
    related_posts_cte AS (
        SELECT jsonb_agg(jsonb_build_object('title', title, 'slug', slug, 'created_at', created_at)) AS related_posts_data
        FROM (
            SELECT DISTINCT bp.title, bp.slug, bp.created_at
            FROM blog_posts bp
            JOIN post_tags pt1 ON bp.id = pt1.post_id
            JOIN post_tags pt2 ON pt1.tag_id = pt2.tag_id
            CROSS JOIN main_post
            WHERE pt2.post_id = main_post.post_id
              AND bp.id != main_post.post_id
            ORDER BY bp.created_at DESC
            LIMIT 10
        ) AS related
    )
SELECT
    (SELECT post_data FROM main_post),
    (SELECT recent_posts_data FROM recent_posts_cte),
    (SELECT related_posts_data FROM related_posts_cte);
END;
$$ LANGUAGE plpgsql;
   
   
CREATE OR REPLACE FUNCTION search_blog_posts(search TEXT, limit_param INTEGER DEFAULT NULL)
RETURNS TABLE(
    id INTEGER,
    rubrik TEXT,
    underrubrik TEXT,
    slug TEXT,
    score DOUBLE PRECISION
) AS $$
BEGIN
RETURN QUERY EXECUTE
    'WITH aggregated_tags AS (
        SELECT 
            bp.id,
            bp.title AS rubrik,
            bp.subtitle AS underrubrik,
            bp.slug,
            COALESCE(STRING_AGG(t.name, '' ''), '''') AS all_tags
        FROM blog_posts bp
        LEFT JOIN post_tags pt ON bp.id = pt.post_id
        LEFT JOIN tags t ON pt.tag_id = t.id
        GROUP BY bp.id
    )
    SELECT 
        id, 
        rubrik, 
        underrubrik, 
        slug,
        CAST(
            ts_rank(
                setweight(to_tsvector(rubrik), ''A'') ||
                setweight(to_tsvector(underrubrik), ''B'') ||
                setweight(to_tsvector(all_tags), ''C''),
                to_tsquery(
                    array_to_string(
                        ARRAY(SELECT unnest(string_to_array($1, '' '')) || '':*''), '' | ''
                    )
                )
            ) AS double precision
        ) AS score
    FROM aggregated_tags
    WHERE to_tsvector(rubrik || '' '' || underrubrik || '' '' || all_tags) @@ to_tsquery(
        array_to_string(
            ARRAY(SELECT unnest(string_to_array($1, '' '')) || '':*''), '' | ''
        )
    )
    ORDER BY score DESC ' ||
    CASE WHEN limit_param IS NOT NULL THEN 'LIMIT ' || limit_param ELSE '' END
    USING search;
END;
$$ LANGUAGE plpgsql;