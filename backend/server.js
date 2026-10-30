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
        display_name VARCHAR(120) NOT NULL DEFAULT 'Học sinh English 12',
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
    console.log('✅ Khởi tạo Schema Database English 12 hoàn tất.');
  } catch (err) {
    console.error('❌ Lỗi kết nối Neon Database:', err.message);
  }
}

// -------------------------------------------------------------
// 1. Swagger UI & OpenAPI 3.0 Documentation
// -------------------------------------------------------------
const openApiSpec = {
  openapi: '3.0.0',
  info: {
    title: 'English 12 - Luyện Thi THPT Web API',
    version: '1.0.0',
    description: 'Hệ thống RESTful Web API chuẩn phục vụ ứng dụng di động English 12. Tích hợp xác thực tài khoản, lưu trữ tiến độ học SGK, đồng bộ kết quả thi thử THPT và kết nối trực tiếp với Neon Serverless PostgreSQL.',
    contact: {
      name: 'English 12 Engineering Team',
    },
  },
  servers: [
    { url: '/', description: 'Máy chủ hiện tại (Render.com / Localhost)' },
  ],
  tags: [
    { name: 'Authentication', description: 'Xác thực: Đăng ký, Đăng nhập, Google Sign-In' },
    { name: 'User Profile', description: 'Hồ sơ học viên & Lộ trình điểm số THPT' },
    { name: 'Daily Stats & Streak', description: 'Thống kê học tập mỗi ngày, Chuỗi Streak & XP' },
    { name: 'Exams & Practice', description: 'Nộp bài thi thử THPT 40 câu và lưu lịch sử điểm' },
    { name: 'Health & System', description: 'Kiểm tra trạng thái máy chủ và Neon Database' },
  ],
  paths: {
    '/health': {
      get: {
        tags: ['Health & System'],
        summary: 'Kiểm tra máy chủ hoạt động (Health check)',
        responses: {
          200: {
            description: 'Máy chủ đang hoạt động bình thường',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    status: { type: 'string', example: 'healthy' },
                    uptime: { type: 'number', example: 124.5 },
                  },
                },
              },
            },
          },
        },
      },
    },
    '/api/auth/register': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng ký tài khoản mới bằng Email & Mật khẩu',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                  email: { type: 'string', example: 'hocsinh12@gmail.com' },
                  password: { type: 'string', example: 'MatKhau123@' },
                  displayName: { type: 'string', example: 'Minh Anh' },
                },
              },
            },
          },
        },
        responses: {
          201: { description: 'Đăng ký tài khoản thành công' },
          400: { description: 'Thiếu email hoặc mật khẩu' },
        },
      },
    },
    '/api/auth/login': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng nhập bằng Email & Mật khẩu',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                  email: { type: 'string', example: 'hocsinh12@gmail.com' },
                  password: { type: 'string', example: 'MatKhau123@' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Đăng nhập thành công' },
          401: { description: 'Sai tài khoản hoặc mật khẩu' },
        },
      },
    },
    '/api/auth/google': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng nhập / Đăng ký nhanh qua tài khoản Google',
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  email: { type: 'string', example: 'student.google@gmail.com' },
                  displayName: { type: 'string', example: 'Google Student' },
                  avatarUrl: { type: 'string', example: 'https://lh3.googleusercontent.com/...' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Đăng nhập Google thành công' },
        },
      },
    },
    '/api/profile': {
      get: {
        tags: ['User Profile'],
        summary: 'Lấy thông tin hồ sơ và mục tiêu điểm thi THPT của học sinh',
        parameters: [
          { name: 'x-user-id', in: 'header', schema: { type: 'string' }, example: 'usr_1712049200' },
        ],
        responses: {
          200: { description: 'Trả về mục tiêu điểm số, ngày thi, thời gian học mỗi ngày' },
        },
      },
      put: {
        tags: ['User Profile'],
        summary: 'Cập nhật mục tiêu điểm số, thời gian học và chủ đề yêu thích',
        parameters: [
          { name: 'x-user-id', in: 'header', schema: { type: 'string' }, example: 'usr_1712049200' },
        ],
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  targetScore: { type: 'number', example: 8.5 },
                  examDate: { type: 'string', example: '2026-06-27' },
                  dailyMinutes: { type: 'integer', example: 20 },
                  reminderEnabled: { type: 'boolean', example: true },
                  favoriteTopics: {
                    type: 'array',
                    items: { type: 'string' },
                    example: ['Công nghệ', 'Môi trường', 'Du lịch'],
                  },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Cập nhật thành công' },
        },
      },
    },
    '/api/stats/daily': {
      get: {
        tags: ['Daily Stats & Streak'],
        summary: 'Lấy lịch sử học tập 30 ngày gần nhất (Streak & XP)',
        parameters: [
          { name: 'x-user-id', in: 'header', schema: { type: 'string' }, example: 'usr_1712049200' },
        ],
        responses: {
          200: { description: 'Danh sách ngày học và XP tích lũy' },
        },
      },
      post: {
        tags: ['Daily Stats & Streak'],
        summary: 'Ghi nhận số câu đã làm, số câu đúng và cộng điểm XP hôm nay',
        parameters: [
          { name: 'x-user-id', in: 'header', schema: { type: 'string' }, example: 'usr_1712049200' },
        ],
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  statDate: { type: 'string', example: '2026-10-31' },
                  questionsDone: { type: 'integer', example: 20 },
                  correctCount: { type: 'integer', example: 18 },
                  xpEarned: { type: 'integer', example: 50 },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Đồng bộ thống kê thành công' },
        },
      },
    },
    '/api/exams/submit': {
      post: {
        tags: ['Exams & Practice'],
        summary: 'Nộp bài thi thử THPT Quốc gia (40 câu) và lưu kết quả',
        parameters: [
          { name: 'x-user-id', in: 'header', schema: { type: 'string' }, example: 'usr_1712049200' },
        ],
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  examType: { type: 'string', example: 'mock_thpt_de_1' },
                  totalQuestions: { type: 'integer', example: 40 },
                  correctCount: { type: 'integer', example: 34 },
                  score: { type: 'number', example: 8.5 },
                  durationSeconds: { type: 'integer', example: 2450 },
                },
              },
            },
          },
        },
        responses: {
          201: { description: 'Lưu kết quả thi thành công' },
        },
      },
    },
  },
};

// Route trả về OpenAPI Specification JSON
app.get('/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.json(openApiSpec);
});

// Giao diện Swagger UI chuẩn HTML
const swaggerHtml = `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>English 12 - Swagger UI & Web API</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
  <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5.11.0/favicon-32x32.png" />
  <style>
    body {
      margin: 0;
      background: #F8FAFC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    .custom-topbar {
      background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%);
      color: #FFFFFF;
      padding: 16px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      box-shadow: 0 4px 12px rgba(15, 23, 42, 0.15);
      border-bottom: 3px solid #F59E0B;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
      color: #FFFFFF;
    }
    .brand-title {
      font-size: 20px;
      font-weight: 900;
      letter-spacing: -0.5px;
    }
    .brand-badge {
      background: #F59E0B;
      color: #0F172A;
      font-size: 11px;
      font-weight: 800;
      padding: 2px 8px;
      border-radius: 999px;
      text-transform: uppercase;
    }
    .status-pill {
      background: rgba(16, 185, 129, 0.2);
      border: 1px solid #10B981;
      color: #34D399;
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      background: #10B981;
      border-radius: 50%;
      box-shadow: 0 0 8px #10B981;
    }
    .swagger-ui {
      max-width: 1400px;
      margin: 0 auto;
      padding: 20px;
    }
    .swagger-ui .topbar { display: none !important; }
  </style>
</head>
<body>
  <div class="custom-topbar">
    <div class="brand">
      <span style="font-size: 28px;">🎓</span>
      <div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="brand-title">English 12 Web API</span>
          <span class="brand-badge">Swagger OAS 3.0</span>
        </div>
        <div style="font-size: 12px; color: #94A3B8; font-weight: 500;">
          Luyện Thi THPT Tiếng Anh • Render & Neon Serverless PostgreSQL
        </div>
      </div>
    </div>
    <div class="status-pill">
      <span class="status-dot"></span>
      Neon PostgreSQL Connected
    </div>
  </div>

  <div id="swagger-ui"></div>

  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: '/swagger.json',
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: "BaseLayout"
      });
    };
  </script>
</body>
</html>`;

// Khi mở trên trình duyệt (hoặc các đường dẫn /docs, /swagger) -> Hiển thị Swagger UI
app.get(['/docs', '/swagger', '/api-docs'], (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(swaggerHtml);
});

// Trang chủ: Nếu là trình duyệt vào -> hiển thị Swagger UI, nếu app gọi JSON -> trả JSON
app.get('/', (req, res) => {
  const acceptsHtml = req.headers.accept && req.headers.accept.includes('text/html');
  if (acceptsHtml) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(swaggerHtml);
  }

  res.json({
    status: 'online',
    app: 'English 12 - Luyện Thi THPT',
    version: '1.0.0',
    documentation: '/docs',
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
  console.log(`🚀 English 12 Backend API đang chạy tại cổng http://localhost:${port}`);
  await initializeDatabase();
});

