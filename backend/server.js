require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Kết nối Neon PostgreSQL qua SSL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false, // Bắt buộc cho Neon Serverless Postgres
  },
});

// Tự động khởi tạo bảng khi server chạy
async function initializeDatabase() {
  if (!process.env.DATABASE_URL) {
    console.warn('⚠️ Cảnh báo: DATABASE_URL chưa được thiết lập. Server đang chạy ở chế độ in-memory demo.');
    return;
  }
  try {
    const client = await pool.connect();
    console.log('✅ Đã kết nối thành công tới Neon PostgreSQL Database!');
    
    // Tạo bảng cơ bản nếu chưa có
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        display_name VARCHAR(120) NOT NULL DEFAULT 'Học sinh Prep12',
        avatar_url TEXT,
        auth_provider VARCHAR(32) NOT NULL DEFAULT 'email',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS user_profiles (
        user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        target_score NUMERIC(3, 1) DEFAULT 8.0,
        exam_date DATE DEFAULT '2026-06-27',
        daily_minutes INT DEFAULT 20,
        reminder_enabled BOOLEAN DEFAULT TRUE,
        reminder_time VARCHAR(8) DEFAULT '20:00',
        favorite_topics TEXT DEFAULT 'Công nghệ,Môi trường',
        current_streak INT DEFAULT 0,
        total_xp INT DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS daily_stats (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
        stat_date DATE NOT NULL,
        questions_done INT DEFAULT 0,
        correct_count INT DEFAULT 0,
        xp_earned INT DEFAULT 0,
        CONSTRAINT unique_user_daily_stat UNIQUE (user_id, stat_date)
      );

      CREATE TABLE IF NOT EXISTS exam_attempts (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
        exam_type VARCHAR(64) NOT NULL,
        total_questions INT NOT NULL DEFAULT 40,
        correct_count INT NOT NULL DEFAULT 0,
        score NUMERIC(4, 2) NOT NULL DEFAULT 0.0,
        duration_seconds INT NOT NULL DEFAULT 0,
        submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    client.release();
    console.log('✅ Khởi tạo Schema Database Prep12 hoàn tất.');
  } catch (err) {
    console.error('❌ Lỗi kết nối Neon Database:', err.message);
  }
}

// -------------------------------------------------------------
// 1. Health check & Trang chủ API
// -------------------------------------------------------------
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    app: 'Prep12 - Luyện Thi THPT Tiếng Anh',
    version: '1.0.0',
    database: process.env.DATABASE_URL ? 'Neon Postgres Connected' : 'No DB Configured',
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', uptime: process.uptime() });
});

// -------------------------------------------------------------
// 2. Authentication: Register, Login, Google Auth
// -------------------------------------------------------------
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, displayName } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email và mật khẩu không được để trống' });
    }

    const userId = 'usr_' + Date.now();
    const name = displayName || email.split('@')[0];

    if (process.env.DATABASE_URL) {
      await pool.query(
        'INSERT INTO users (id, email, password_hash, display_name, auth_provider) VALUES ($1, $2, $3, $4, $5)',
        [userId, email, password, name, 'email']
      );
      await pool.query(
        'INSERT INTO user_profiles (user_id) VALUES ($1)',
        [userId]
      );
    }

    res.status(201).json({
      message: 'Đăng ký thành công',
      user: {
        id: userId,
        email,
        displayName: name,
        authProvider: 'email',
      },
      token: 'jwt_mock_token_' + userId,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Vui lòng cung cấp email và mật khẩu' });
    }

    let user = {
      id: 'usr_default',
      email,
      displayName: email.split('@')[0],
      authProvider: 'email',
    };

    if (process.env.DATABASE_URL) {
      const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Tài khoản không tồn tại' });
      }
      user = result.rows[0];
    }

    res.json({
      message: 'Đăng nhập thành công',
      user,
      token: 'jwt_mock_token_' + user.id,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/google', async (req, res) => {
  try {
    const { email, displayName, avatarUrl } = req.body;
    const googleEmail = email || 'student.google@gmail.com';
    const googleName = displayName || 'Google Student';
    const userId = 'gg_' + Date.now();

    if (process.env.DATABASE_URL) {
      await pool.query(
        `INSERT INTO users (id, email, display_name, avatar_url, auth_provider)
         VALUES ($1, $2, $3, $4, 'google')
         ON CONFLICT (email) DO UPDATE SET display_name = EXCLUDED.display_name
         RETURNING *`,
        [userId, googleEmail, googleName, avatarUrl || '']
      );
      await pool.query(
        `INSERT INTO user_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
        [userId]
      );
    }

    res.json({
      message: 'Đăng nhập Google thành công',
      user: {
        id: userId,
        email: googleEmail,
        displayName: googleName,
        authProvider: 'google',
      },
      token: 'jwt_google_token_' + userId,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 3. User Profile & Study Plan (Mục tiêu điểm, thời gian, chủ đề)
// -------------------------------------------------------------
app.get('/api/profile', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] || 'guest_user';
    if (!process.env.DATABASE_URL) {
      return res.json({
        targetScore: 8.0,
        examDate: '2026-06-27',
        dailyMinutes: 20,
        reminderEnabled: true,
        reminderTime: '20:00',
        favoriteTopics: ['Công nghệ', 'Môi trường'],
        streak: 3,
        xp: 120,
      });
    }

    const result = await pool.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
    if (result.rows.length === 0) {
      return res.json({ targetScore: 8.0, dailyMinutes: 20 });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/profile', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] || 'guest_user';
    const { targetScore, examDate, dailyMinutes, reminderEnabled, favoriteTopics } = req.body;

    if (process.env.DATABASE_URL) {
      await pool.query(
        `INSERT INTO user_profiles (user_id, target_score, exam_date, daily_minutes, reminder_enabled, favorite_topics)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (user_id) DO UPDATE SET
            target_score = EXCLUDED.target_score,
            exam_date = EXCLUDED.exam_date,
            daily_minutes = EXCLUDED.daily_minutes,
            reminder_enabled = EXCLUDED.reminder_enabled,
            favorite_topics = EXCLUDED.favorite_topics`,
        [userId, targetScore || 8.0, examDate || '2026-06-27', dailyMinutes || 20, reminderEnabled !== false, Array.isArray(favoriteTopics) ? favoriteTopics.join(',') : '']
      );
    }

    res.json({ message: 'Cập nhật lộ trình học thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 4. Daily Stats & Streak Sync
// -------------------------------------------------------------
app.get('/api/stats/daily', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] || 'guest_user';
    if (!process.env.DATABASE_URL) {
      return res.json([
        { date: '2026-10-30', questionsDone: 15, correctCount: 13, xp: 60 },
      ]);
    }
    const result = await pool.query('SELECT * FROM daily_stats WHERE user_id = $1 ORDER BY stat_date DESC LIMIT 30', [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/stats/daily', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] || 'guest_user';
    const { statDate, questionsDone, correctCount, xpEarned } = req.body;

    if (process.env.DATABASE_URL) {
      await pool.query(
        `INSERT INTO daily_stats (user_id, stat_date, questions_done, correct_count, xp_earned)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (user_id, stat_date) DO UPDATE SET
            questions_done = daily_stats.questions_done + EXCLUDED.questions_done,
            correct_count = daily_stats.correct_count + EXCLUDED.correct_count,
            xp_earned = daily_stats.xp_earned + EXCLUDED.xp_earned`,
        [userId, statDate || new Date().toISOString().split('T')[0], questionsDone || 0, correctCount || 0, xpEarned || 0]
      );
    }

    res.json({ message: 'Đồng bộ thống kê thành công' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 5. Exam Attempts (Lưu kết quả thi thử 40 câu)
// -------------------------------------------------------------
app.post('/api/exams/submit', async (req, res) => {
  try {
    const userId = req.headers['x-user-id'] || 'guest_user';
    const { examType, totalQuestions, correctCount, score, durationSeconds } = req.body;
    const attemptId = 'atm_' + Date.now();

    if (process.env.DATABASE_URL) {
      await pool.query(
        `INSERT INTO exam_attempts (id, user_id, exam_type, total_questions, correct_count, score, duration_seconds)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [attemptId, userId, examType || 'mock_thpt', totalQuestions || 40, correctCount || 0, score || 0.0, durationSeconds || 0]
      );
    }

    res.status(201).json({
      message: 'Lưu kết quả thi thành công',
      attemptId,
      score,
      xpEarned: Math.round((correctCount || 0) * 5),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Khởi chạy server
app.listen(port, async () => {
  console.log(`🚀 Prep12 Backend API đang chạy tại cổng http://localhost:${port}`);
  await initializeDatabase();
});

