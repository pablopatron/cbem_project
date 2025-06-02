-- =============================================
-- CORE ENTITIES (Base Classes in OOP terms)
-- =============================================

-- User entity (base class for all user types)
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,  -- Encrypted storage
    first_name TEXT,
    last_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    eco_score INTEGER DEFAULT 0,
    last_login DATETIME,
    status TEXT CHECK(status IN ('active', 'suspended', 'banned')) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    verification_token TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    password_reset_token TEXT,
    reset_token_expires DATETIME
);

-- Content entity (abstract base for posts, comments, etc.)
CREATE TABLE content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL CHECK(content_type IN ('post', 'comment', 'event', 'poll')),
    user_id INTEGER NOT NULL,
    body TEXT NOT NULL,
    status TEXT CHECK(status IN ('draft', 'published', 'archived', 'flagged')) DEFAULT 'published',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================
-- INHERITED ENTITIES (Specializations)
-- =============================================

-- Post specialization (inherits from content)
CREATE TABLE posts (
    content_id INTEGER PRIMARY KEY,
    title TEXT,
    impact_level TEXT CHECK(impact_level IN ('low', 'medium', 'high')),
    carbon_saved REAL,  -- kg of CO2 saved
    is_featured BOOLEAN DEFAULT FALSE,
    location_lat REAL,
    location_long REAL,
    FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
);

-- Comment specialization (inherits from content)
CREATE TABLE comments (
    content_id INTEGER PRIMARY KEY,
    parent_id INTEGER,  -- For nested comments
    post_id INTEGER NOT NULL,
    FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(content_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(content_id) ON DELETE CASCADE
);

-- =============================================
-- COMPOSITION & AGGREGATION RELATIONSHIPS
-- =============================================

-- Media attachments (polymorphic relationship)
CREATE TABLE media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id INTEGER NOT NULL,
    media_type TEXT NOT NULL CHECK(media_type IN ('image', 'video', 'document')),
    url TEXT NOT NULL,
    thumbnail_url TEXT,
    alt_text TEXT,
    width INTEGER,
    height INTEGER,
    file_size INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE
);

-- Reactions (polymorphic - can apply to posts or comments)
CREATE TABLE reactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    reaction_type TEXT NOT NULL CHECK(reaction_type IN ('like', 'dislike', 'love', 'laugh', 'sad', 'angry', 'eco')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(content_id, user_id, reaction_type),  -- One reaction type per user per content
    FOREIGN KEY (content_id) REFERENCES content(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================
-- ADVANCED FEATURE TABLES
-- =============================================

-- User relationships (following/friends)
CREATE TABLE user_relationships (
    follower_id INTEGER NOT NULL,
    followed_id INTEGER NOT NULL,
    relationship_type TEXT CHECK(relationship_type IN ('follow', 'friend', 'block')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, followed_id),
    FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (followed_id) REFERENCES users(id) ON DELETE CASCADE,
    CHECK(follower_id != followed_id)  -- Prevent self-follow
);

-- Notifications
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    notification_type TEXT NOT NULL CHECK(notification_type IN (
        'reaction', 'comment', 'follow', 'mention', 'system', 'event'
    )),
    source_id INTEGER,  -- ID of the content/user that triggered notification
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Events (for community activities)
CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    organizer_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    location TEXT,
    max_attendees INTEGER,
    carbon_impact REAL,  -- Estimated impact of attending
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organizer_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Event attendees
CREATE TABLE event_attendees (
    event_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    status TEXT CHECK(status IN ('going', 'interested', 'not_going')) DEFAULT 'going',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id, user_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Groups/communities
CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    avatar_url TEXT,
    banner_url TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    created_by INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Group members
CREATE TABLE group_members (
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role TEXT CHECK(role IN ('member', 'moderator', 'admin')) DEFAULT 'member',
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Group posts (separate from regular posts)
CREATE TABLE group_posts (
    post_id INTEGER NOT NULL,
    group_id INTEGER NOT NULL,
    pinned BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (post_id, group_id),
    FOREIGN KEY (post_id) REFERENCES posts(content_id) ON DELETE CASCADE,
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
);

-- =============================================
-- ENVIRONMENTAL IMPACT TRACKING
-- =============================================

-- User environmental actions
CREATE TABLE eco_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    action_type TEXT NOT NULL CHECK(action_type IN (
        'recycle', 'compost', 'bike', 'public_transport', 'meatless_meal', 
        'solar_usage', 'water_saved', 'tree_planted', 'waste_reduced'
    )),
    quantity REAL NOT NULL,  -- e.g., kg of waste, liters of water
    carbon_saved REAL,  -- kg of CO2 equivalent
    verified BOOLEAN DEFAULT FALSE,
    verified_by INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Badges/awards for environmental achievements
CREATE TABLE badges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    criteria TEXT NOT NULL  -- e.g., "Plant 10 trees" or "Reduce carbon by 100kg"
);

-- User earned badges
CREATE TABLE user_badges (
    user_id INTEGER NOT NULL,
    badge_id INTEGER NOT NULL,
    earned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, badge_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (badge_id) REFERENCES badges(id) ON DELETE CASCADE
);

-- =============================================
-- SAMPLE DATA INSERTION (with OOP relationships)
-- =============================================

-- Insert sample users (instances of User class)
INSERT INTO users (username, email, password_hash, first_name, last_name, eco_score) VALUES
('eco_warrior', 'warrior@example.com', 'hashed_pw1', 'Jane', 'Doe', 85),
('green_thumb', 'gardener@example.com', 'hashed_pw2', 'John', 'Smith', 72),
('climate_champ', 'champ@example.com', 'hashed_pw3', 'Alex', 'Morgan', 91),
('recycle_king', 'recycler@example.com', 'hashed_pw4', 'Sam', 'Wilson', 65),
('solar_guru', 'solar@example.com', 'hashed_pw5', 'Priya', 'Patel', 88);

-- Insert content (base class instances)
INSERT INTO content (content_type, user_id, body, status) VALUES
('post', 1, 'Just switched to a bamboo toothbrush! Small changes make big differences. #ZeroWaste', 'published'),
('post', 2, 'Community garden produced 200kg of vegetables this season! Reducing food miles.', 'published'),
('post', 3, 'Guide to reducing plastic in your kitchen - 10 easy swaps', 'published'),
('post', 4, 'How I reduced my waste by 90% in 6 months', 'published'),
('post', 5, 'Solar panel installation - was it worth it? My 1-year review', 'published');

-- Insert posts (specialized content)
INSERT INTO posts (content_id, title, impact_level, carbon_saved) VALUES
(1, 'Bamboo Toothbrush Switch', 'high', 0.5),
(2, 'Community Garden Harvest', 'medium', 25.0),
(3, 'Plastic-Free Kitchen Guide', 'high', 10.0),
(4, 'Waste Reduction Journey', 'high', 50.0),
(5, 'Solar Panel Review', 'high', 200.0);

-- Insert media (composition relationship)
INSERT INTO media (content_id, media_type, url, alt_text) VALUES
(1, 'image', 'bamboo-brush.jpg', 'Bamboo toothbrush on bathroom counter'),
(2, 'image', 'garden-harvest.jpg', 'Vegetables from community garden'),
(3, 'image', 'plastic-free-kitchen.jpg', 'Kitchen with glass containers'),
(4, 'image', 'zero-waste-home.jpg', 'Home organization with minimal waste'),
(5, 'image', 'solar-panels.jpg', 'Roof with solar panels');

-- Insert reactions (polymorphic relationship)
INSERT INTO reactions (content_id, user_id, reaction_type) VALUES
(1, 2, 'like'),
(1, 3, 'love'),
(1, 4, 'eco'),
(2, 1, 'like'),
(2, 5, 'eco'),
(3, 1, 'like'),
(3, 2, 'love'),
(4, 3, 'eco'),
(5, 4, 'like'),
(5, 1, 'eco');

-- Insert comments (inherited from content)
INSERT INTO content (content_type, user_id, body, status) VALUES
('comment', 2, 1, 'Great post! Where did you buy your bamboo brush?', 'published'),
('comment', 3, 1, 'I made this switch last year - never going back!', 'published'),
('comment', 1, 2, 'Can I join your garden next season?', 'published');

INSERT INTO comments (content_id, post_id) VALUES
(6, 1),
(7, 1),
(8, 2);

-- Insert user relationships
INSERT INTO user_relationships (follower_id, followed_id, relationship_type) VALUES
(2, 1, 'follow'),
(3, 1, 'follow'),
(1, 2, 'follow'),
(4, 1, 'follow'),
(5, 1, 'follow');

-- =============================================
-- ADVANCED QUERIES (Demonstrating OOP Relationships)
-- =============================================

-- Polymorphic content query (posts and comments)
SELECT 
    c.id,
    c.content_type,
    u.username AS author,
    c.body,
    c.created_at,
    CASE 
        WHEN c.content_type = 'post' THEN p.title
        ELSE 'Comment on: ' || parent_p.title
    END AS title,
    COUNT(r.id) AS reaction_count
FROM 
    content c
JOIN 
    users u ON c.user_id = u.id
LEFT JOIN 
    posts p ON c.id = p.content_id AND c.content_type = 'post'
LEFT JOIN 
    comments cm ON c.id = cm.content_id AND c.content_type = 'comment'
LEFT JOIN 
    posts parent_p ON cm.post_id = parent_p.content_id
LEFT JOIN 
    reactions r ON c.id = r.content_id
GROUP BY 
    c.id
ORDER BY 
    c.created_at DESC;

-- User profile with aggregated data (encapsulation)
SELECT 
    u.id,
    u.username,
    u.eco_score,
    COUNT(DISTINCT p.content_id) AS post_count,
    COUNT(DISTINCT r.id) AS reaction_count,
    COUNT(DISTINCT f.followed_id) AS following_count,
    COUNT(DISTINCT f2.follower_id) AS follower_count,
    (SELECT SUM(carbon_saved) FROM eco_actions WHERE user_id = u.id) AS total_carbon_saved
FROM 
    users u
LEFT JOIN 
    content p ON u.id = p.user_id AND p.content_type = 'post'
LEFT JOIN 
    reactions r ON u.id = r.user_id
LEFT JOIN 
    user_relationships f ON u.id = f.follower_id
LEFT JOIN 
    user_relationships f2 ON u.id = f2.followed_id
WHERE 
    u.id = 1
GROUP BY 
    u.id;

-- Environmental impact dashboard (abstraction)
SELECT 
    u.username,
    COUNT(DISTINCT ea.id) AS action_count,
    SUM(ea.carbon_saved) AS total_carbon_saved,
    COUNT(DISTINCT ub.badge_id) AS badge_count,
    (SELECT COUNT(DISTINCT post_id) 
     FROM posts p JOIN content c ON p.content_id = c.id 
     WHERE c.user_id = u.id AND p.impact_level = 'high') AS high_impact_posts
FROM 
    users u
LEFT JOIN 
    eco_actions ea ON u.id = ea.user_id
LEFT JOIN 
    user_badges ub ON u.id = ub.user_id
GROUP BY 
    u.id
ORDER BY 
    total_carbon_saved DESC;