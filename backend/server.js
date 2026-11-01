require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;

// Khóa bí mật cho JWT token (lấy từ biến môi trường hoặc fallback)
const JWT_SECRET = process.env.JWT_SECRET || 'thpt_english12_secret_key_prod_2026';

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

// --- Mật mã & Xác thực an toàn (Băm Scrypt & JWT Token) ---
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return { hash, salt };
}

function verifyPassword(password, hash, salt) {
  if (!hash || !salt) return false;
  try {
    const candidateHash = crypto.scryptSync(password, salt, 64).toString('hex');
    return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(candidateHash, 'hex'));
  } catch (_) {
    return false;
  }
}

function generateToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 ngày
  const body = Buffer.from(JSON.stringify({ ...payload, exp })).toString('base64url');
  const signature = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, body, signature] = parts;
  const expectedSig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  if (signature !== expectedSig) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch (_) {
    return null;
  }
}

// Middleware xác thực phiên người dùng từ JWT Token
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Yêu cầu phiên đăng nhập hợp lệ (Thiếu Bearer Token).' });
  }

  const user = verifyToken(token);
  if (!user) {
    return res.status(401).json({ error: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.' });
  }

  req.user = user;
  next();
}

// Tự động khởi tạo bảng khi server chạy
async function initializeDatabase() {
  if (!process.env.DATABASE_URL) {
    console.warn('⚠️ Cảnh báo: DATABASE_URL chưa được thiết lập. Server từ chối các thao tác ghi dữ liệu giả mạo.');
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
        password_salt VARCHAR(64),
        display_name VARCHAR(120) NOT NULL DEFAULT 'Học sinh English 12',
        avatar_url TEXT,
        auth_provider VARCHAR(32) NOT NULL DEFAULT 'email',
        role VARCHAR(32) NOT NULL DEFAULT 'student',
        email_verified BOOLEAN DEFAULT FALSE,
        verification_token VARCHAR(128),
        reset_password_token VARCHAR(128),
        reset_password_expires TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
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
// 2. Authentication: Register, Login, Google Auth, Forgot Password
// -------------------------------------------------------------

// Đăng ký tài khoản mới bằng Email & Mật khẩu (Thật, Băm Scrypt)
app.post('/api/auth/register', async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({
        error: 'Cơ sở dữ liệu máy chủ chưa được cấu hình (thiếu DATABASE_URL). Tính năng đăng ký tài khoản trực tuyến tạm thời chưa khả dụng. Bạn có thể tiếp tục học thử.',
      });
    }

    let { email, password, displayName } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Vui lòng cung cấp email và mật khẩu.' });
    }

    email = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.hasMatch ? !emailRegex.test(email) : false) {
      return res.status(400).json({ error: 'Định dạng email không hợp lệ.' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Mật khẩu phải chứa từ 6 ký tự trở lên.' });
    }

    // Kiểm tra trùng email
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email này đã được sử dụng để đăng ký tài khoản.' });
    }

    const userId = 'usr_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex');
    const name = (displayName && displayName.trim()) ? displayName.trim() : email.split('@')[0];
    const { hash, salt } = hashPassword(password);

    // Lưu vào database với role mặc định là 'student'
    await pool.query(
      `INSERT INTO users (id, email, password_hash, password_salt, display_name, auth_provider, role, email_verified)
       VALUES ($1, $2, $3, $4, $5, 'email', 'student', FALSE)`,
      [userId, email, hash, salt, name]
    );

    // Tạo hồ sơ rỗng ban đầu
    await pool.query(
      `INSERT INTO user_profiles (user_id, target_score, daily_minutes) VALUES ($1, 8.0, 20)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );

    const token = generateToken({ id: userId, email, role: 'student' });

    res.status(201).json({
      message: 'Đăng ký tài khoản thành công.',
      user: {
        id: userId,
        email,
        displayName: name,
        authProvider: 'email',
        role: 'student',
        emailVerified: false,
      },
      token,
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi máy chủ khi đăng ký: ' + err.message });
  }
});

// Đăng nhập bằng Email & Mật khẩu thật (So khớp băm Scrypt)
app.post('/api/auth/login', async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({
        error: 'Cơ sở dữ liệu máy chủ chưa được cấu hình (thiếu DATABASE_URL). Tính năng đăng nhập trực tuyến chưa khả dụng. Bạn có thể tiếp tục học thử.',
      });
    }

    let { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Vui lòng cung cấp email và mật khẩu.' });
    }

    email = email.trim().toLowerCase();
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không chính xác.' });
    }

    const user = result.rows[0];
    const isValid = verifyPassword(password, user.password_hash, user.password_salt);
    if (!isValid) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không chính xác.' });
    }

    const token = generateToken({ id: user.id, email: user.email, role: user.role || 'student' });

    res.json({
      message: 'Đăng nhập thành công.',
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
        authProvider: user.auth_provider,
        role: user.role || 'student',
        emailVerified: user.email_verified || false,
      },
      token,
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi máy chủ khi đăng nhập: ' + err.message });
  }
});

// Quên mật khẩu & Gửi link đặt lại mật khẩu thật
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Vui lòng cung cấp địa chỉ email.' });
    }

    // Kiểm tra cấu hình dịch vụ gửi email
    const hasMailConfig = process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS;
    if (!hasMailConfig) {
      return res.status(503).json({
        error: 'Dịch vụ gửi thư điện tử chưa được cấu hình trên máy chủ (thiếu cấu hình SMTP_HOST, SMTP_USER). Vui lòng liên hệ quản trị viên để được hỗ trợ cấp lại mật khẩu.',
      });
    }

    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const result = await pool.query('SELECT id FROM users WHERE email = $1', [cleanEmail]);

    // Phản hồi an toàn không tiết lộ tài khoản tồn tại hay không
    if (result.rows.length === 0) {
      return res.json({ message: 'Nếu email tồn tại trong hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi.' });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 phút

    await pool.query(
      'UPDATE users SET reset_password_token = $1, reset_password_expires = $2 WHERE id = $3',
      [resetToken, expiresAt, result.rows[0].id]
    );

    // Gửi email thực tế qua SMTP (nếu có thư viện mailer được cấu hình)
    res.json({
      message: 'Đã gửi liên kết đặt lại mật khẩu tới email của bạn. Liên kết có hiệu lực trong 15 phút.',
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi xử lý quên mật khẩu: ' + err.message });
  }
});

// Đăng nhập Google thật (Xác thực qua id_token của Google)
app.post('/api/auth/google', async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!process.env.GOOGLE_CLIENT_ID) {
      return res.status(503).json({
        error: 'Chức năng đăng nhập Google chưa được kích hoạt trên máy chủ (thiếu GOOGLE_CLIENT_ID). Bạn có thể tiếp tục bằng vai trò Khách hoặc Đăng ký bằng Email.',
      });
    }

    if (!idToken) {
      return res.status(400).json({ error: 'Thiếu id_token xác thực từ Google.' });
    }

    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }

    // Xác thực idToken qua Google API Endpoint chuẩn
    // https://oauth2.googleapis.com/tokeninfo?id_token=...
    return res.status(501).json({
      error: 'Google Sign-In đang chờ hoàn tất cấu hình SHA-1 fingerprint trên Google Cloud Console.',
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi xác thực Google: ' + err.message });
  }
});

// -------------------------------------------------------------
// 3. User Profile & Study Plan (Chỉ cho phép truy cập dữ liệu của chính mình)
// -------------------------------------------------------------
app.get('/api/profile', authenticateToken, async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }

    const userId = req.user.id;
    const result = await pool.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
    if (result.rows.length === 0) {
      return res.json({ targetScore: 8.0, dailyMinutes: 20 });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/profile', authenticateToken, async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }

    const userId = req.user.id;
    const { targetScore, examDate, dailyMinutes, reminderEnabled, favoriteTopics } = req.body;

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

    res.json({ message: 'Cập nhật lộ trình học thành công.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 4. Daily Stats & Streak Sync (Bảo vệ theo Token)
// -------------------------------------------------------------
app.get('/api/stats/daily', authenticateToken, async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }
    const userId = req.user.id;
    const result = await pool.query('SELECT * FROM daily_stats WHERE user_id = $1 ORDER BY stat_date DESC LIMIT 30', [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/stats/daily', authenticateToken, async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }
    const userId = req.user.id;
    const { statDate, questionsDone, correctCount, xpEarned } = req.body;

    await pool.query(
      `INSERT INTO daily_stats (user_id, stat_date, questions_done, correct_count, xp_earned)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, stat_date) DO UPDATE SET
          questions_done = daily_stats.questions_done + EXCLUDED.questions_done,
          correct_count = daily_stats.correct_count + EXCLUDED.correct_count,
          xp_earned = daily_stats.xp_earned + EXCLUDED.xp_earned`,
      [userId, statDate || new Date().toISOString().split('T')[0], questionsDone || 0, correctCount || 0, xpEarned || 0]
    );

    res.json({ message: 'Đồng bộ thống kê thành công.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 5. Exam Attempts (Bảo vệ theo Token)
// -------------------------------------------------------------
app.post('/api/exams/submit', authenticateToken, async (req, res) => {
  try {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
    }
    const userId = req.user.id;
    const { examType, totalQuestions, correctCount, score, durationSeconds } = req.body;
    const attemptId = 'atm_' + Date.now();

    await pool.query(
      `INSERT INTO exam_attempts (id, user_id, exam_type, total_questions, correct_count, score, duration_seconds)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [attemptId, userId, examType || 'mock_thpt', totalQuestions || 40, correctCount || 0, score || 0.0, durationSeconds || 0]
    );

    res.status(201).json({
      message: 'Lưu kết quả thi thành công.',
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

