-- ====================================================================
-- SCHEMA POSTGRESQL CHO ỨNG DỤNG ENGLISH 12 (NEON DATABASE)
-- ====================================================================

-- 1. Bảng Người dùng (Tài khoản)
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    google_id VARCHAR(128) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    password_salt VARCHAR(64),
    display_name VARCHAR(120) NOT NULL DEFAULT 'Học sinh English 12',
    avatar_url TEXT,
    auth_provider VARCHAR(32) NOT NULL DEFAULT 'email', -- 'email', 'google', 'guest'
    role VARCHAR(32) NOT NULL DEFAULT 'student', -- 'student', 'teacher', 'admin'
    email_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(128),
    reset_password_token VARCHAR(128),
    reset_password_expires TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Bảng Hồ sơ & Lộ trình học (Điểm mục tiêu, thời gian, chủ đề)
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    target_score NUMERIC(3, 1) DEFAULT 8.0,
    exam_date DATE DEFAULT '2026-06-27',
    daily_minutes INT DEFAULT 20,
    reminder_enabled BOOLEAN DEFAULT TRUE,
    reminder_time VARCHAR(8) DEFAULT '20:00',
    favorite_topics TEXT DEFAULT 'Công nghệ,Môi trường,Khoa học',
    current_streak INT DEFAULT 0,
    total_xp INT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Bảng Thống kê học tập hàng ngày (Streak & XP)
CREATE TABLE IF NOT EXISTS daily_stats (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL,
    questions_done INT DEFAULT 0,
    correct_count INT DEFAULT 0,
    xp_earned INT DEFAULT 0,
    time_spent_seconds INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_daily_stat UNIQUE (user_id, stat_date)
);

-- 4. Bảng Tiến độ học Sách giáo khoa theo Unit & Section
CREATE TABLE IF NOT EXISTS textbook_progress (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    unit_number INT NOT NULL,
    section_name VARCHAR(64) NOT NULL,
    status VARCHAR(32) DEFAULT 'completed', -- 'completed', 'in_progress', 'not_started'
    score INT DEFAULT 0,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_unit_section UNIQUE (user_id, unit_number, section_name)
);

-- 5. Bảng Lịch sử làm bài thi thử THPT
CREATE TABLE IF NOT EXISTS exam_attempts (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    exam_type VARCHAR(64) NOT NULL, -- 'mock_thpt', 'topic_practice'
    total_questions INT NOT NULL DEFAULT 40,
    correct_count INT NOT NULL DEFAULT 0,
    score NUMERIC(4, 2) NOT NULL DEFAULT 0.0,
    duration_seconds INT NOT NULL DEFAULT 0,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Bảng Sổ câu sai (Wrong Book) ôn tập lặp lại ngắt quãng (SRS)
CREATE TABLE IF NOT EXISTS wrong_book (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    question_id VARCHAR(64) NOT NULL,
    wrong_answer TEXT,
    correct_answer TEXT,
    wrong_count INT DEFAULT 1,
    next_review_at TIMESTAMP WITH TIME ZONE,
    is_mastered BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_wrong_question UNIQUE (user_id, question_id)
);

-- Index tối ưu truy vấn
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date ON daily_stats(user_id, stat_date);
CREATE INDEX IF NOT EXISTS idx_textbook_progress_user ON textbook_progress(user_id, unit_number);

-- Bổ sung các cột mới nếu bảng users đã được tạo từ trước
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_salt VARCHAR(64);
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(32) NOT NULL DEFAULT 'email';
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(32) NOT NULL DEFAULT 'student';
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_password_token VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_password_expires TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

