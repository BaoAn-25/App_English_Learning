require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;

// Khóa bí mật cho JWT token (lấy từ biến môi trường hoặc khóa an toàn dự phòng)
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.warn('⚠️ Cảnh báo: Biến JWT_SECRET chưa được thiết lập. Sử dụng khóa an toàn dự phòng cho phiên làm việc.');
}
const ACTIVE_JWT_SECRET = JWT_SECRET || 'thpt_english12_production_secret_key_2026_neon';

// Cấu hình dịch vụ gửi email Nodemailer
let mailerTransporter = null;
if (process.env.SMTP_USER && process.env.SMTP_PASS) {
  try {
    const nodemailer = require('nodemailer');
    const cleanPass = String(process.env.SMTP_PASS).replace(/\s+/g, '');
    const isGmail = (process.env.SMTP_HOST && process.env.SMTP_HOST.includes('gmail')) ||
                    (process.env.SMTP_USER && process.env.SMTP_USER.includes('@gmail.com'));

    const transportConfig = isGmail
      ? {
          service: 'gmail',
          auth: {
            user: process.env.SMTP_USER.trim(),
            pass: cleanPass,
          },
          connectionTimeout: 4000,
          greetingTimeout: 4000,
          socketTimeout: 6000,
        }
      : {
          host: process.env.SMTP_HOST || 'smtp.gmail.com',
          port: parseInt(process.env.SMTP_PORT || '587', 10),
          secure: process.env.SMTP_PORT === '465',
          auth: {
            user: process.env.SMTP_USER.trim(),
            pass: cleanPass,
          },
          connectionTimeout: 4000,
          greetingTimeout: 4000,
          socketTimeout: 6000,
        };

    mailerTransporter = nodemailer.createTransport(transportConfig);
    console.log('✅ Dịch vụ gửi thư điện tử SMTP đã được cấu hình thành công.');
  } catch (err) {
    console.warn('⚠️ Không thể khởi tạo dịch vụ gửi thư SMTP:', err.message);
  }
} else {
  console.log('ℹ️ Dịch vụ gửi thư SMTP chưa được cấu hình. Các yêu cầu xác minh email và quên mật khẩu sẽ trả về thông báo hướng dẫn.');
}

// Khởi tạo Google OAuth2 Client để xác thực ID Token chuẩn từ Google
const { OAuth2Client } = require('google-auth-library');
const googleOAuthClient = new OAuth2Client();

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

// Giới hạn thử đăng nhập (Rate limiter đơn giản theo IP / email)
const loginAttempts = new Map();
function checkLoginRateLimit(key) {
  const now = Date.now();
  const record = loginAttempts.get(key) || { count: 0, firstAttempt: now };
  if (now - record.firstAttempt > 15 * 60 * 1000) {
    loginAttempts.set(key, { count: 1, firstAttempt: now });
    return true;
  }
  if (record.count >= 8) {
    return false;
  }
  record.count += 1;
  loginAttempts.set(key, record);
  return true;
}

function clearLoginRateLimit(key) {
  loginAttempts.delete(key);
}

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
  const signature = crypto.createHmac('sha256', ACTIVE_JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

function verifyToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, body, signature] = parts;
  const expectedSig = crypto.createHmac('sha256', ACTIVE_JWT_SECRET).update(`${header}.${body}`).digest('base64url');
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
    
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        google_id VARCHAR(128) UNIQUE,
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
        target_score NUMERIC(3, 1),
        exam_date DATE,
        daily_minutes INT DEFAULT 20,
        reminder_enabled BOOLEAN DEFAULT FALSE,
        reminder_time VARCHAR(8) DEFAULT '20:00',
        favorite_topics TEXT,
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

      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
      CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date ON daily_stats(user_id, stat_date);

      -- Tự động bổ sung các cột mới nếu database đã tồn tại từ trước (Tránh lỗi column does not exist)
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

      CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
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
    description: 'Hệ thống RESTful Web API chuẩn phục vụ ứng dụng di động English 12. Tích hợp xác thực tài khoản, đăng nhập Google, đặt lại mật khẩu, lưu trữ tiến độ học SGK, đồng bộ kết quả thi thử THPT và kết nối trực tiếp với Neon Serverless PostgreSQL.',
    contact: {
      name: 'English 12 Engineering Team',
    },
  },
  servers: [
    { url: '/', description: 'Máy chủ hiện tại (Render.com / Localhost)' },
  ],
  tags: [
    { name: 'Authentication', description: 'Xác thực: Đăng ký, Đăng nhập, Google Sign-In, Quên & Đặt lại mật khẩu' },
    { name: 'User Profile', description: 'Hồ sơ học viên & Lộ trình điểm số THPT' },
    { name: 'Daily Stats & Streak', description: 'Thống kê học tập mỗi ngày, Chuỗi Streak & XP' },
    { name: 'Exams & Practice', description: 'Nộp bài thi thử THPT 40 câu và lưu lịch sử điểm' },
    { name: 'AI Tutor', description: 'Trợ lý AI giải đáp thắc mắc ngữ pháp & từ vựng Tiếng Anh 12' },
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
          409: { description: 'Email đã được đăng ký trước đó' },
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
          200: { description: 'Đăng nhập thành công, trả về token và thông tin user' },
          401: { description: 'Sai tài khoản hoặc mật khẩu' },
        },
      },
    },
    '/api/auth/google': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng nhập / Đăng ký nhanh qua tài khoản Google',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idToken'],
                properties: {
                  idToken: { type: 'string', example: 'eyJhbGciOiJSUzI1NiIs...' },
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
    '/api/auth/forgot-password': {
      post: {
        tags: ['Authentication'],
        summary: 'Yêu cầu liên kết đặt lại mật khẩu qua Email (chuẩn Duolingo)',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email'],
                properties: {
                  email: { type: 'string', example: 'hocsinh12@gmail.com' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Tạo mã đặt lại mật khẩu và gửi email thành công' },
        },
      },
    },
    '/api/auth/reset-password': {
      post: {
        tags: ['Authentication'],
        summary: 'Xác nhận mã Token và đặt mật khẩu mới',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['token', 'newPassword'],
                properties: {
                  token: { type: 'string', example: '9a8b7c6d5e4f3a2b1c0d' },
                  newPassword: { type: 'string', example: 'MatKhauMoi123@' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Cập nhật mật khẩu mới thành công' },
          400: { description: 'Token không hợp lệ hoặc đã hết hạn' },
        },
      },
    },
    '/api/profile': {
      get: {
        tags: ['User Profile'],
        summary: 'Lấy thông tin hồ sơ và mục tiêu điểm thi THPT của học sinh',
        parameters: [
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
        ],
        responses: {
          200: { description: 'Trả về mục tiêu điểm số, ngày thi, thời gian học mỗi ngày' },
        },
      },
      put: {
        tags: ['User Profile'],
        summary: 'Cập nhật mục tiêu điểm số, thời gian học và chủ đề yêu thích',
        parameters: [
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
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
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
        ],
        responses: {
          200: { description: 'Danh sách ngày học và XP tích lũy' },
        },
      },
      post: {
        tags: ['Daily Stats & Streak'],
        summary: 'Ghi nhận số câu đã làm, số câu đúng và cộng điểm XP hôm nay',
        parameters: [
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
        ],
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  statDate: { type: 'string', example: '2026-11-04' },
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
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
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
    '/api/ai/ask': {
      post: {
        tags: ['AI Tutor'],
        summary: 'Hỏi trợ lý Gia sư AI về kiến thức Tiếng Anh 12 SGK',
        parameters: [
          { name: 'Authorization', in: 'header', required: true, schema: { type: 'string', example: 'Bearer <jwt_token>' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['question'],
                properties: {
                  question: { type: 'string', example: 'Giải thích giúp em câu điều kiện hỗn hợp loại 3 và loại 2?' },
                  unitNumber: { type: 'integer', example: 5 },
                  section: { type: 'string', example: 'Grammar' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Câu trả lời giải thích từ AI' },
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
      border-bottom: 3px solid #1CB0F6;
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
      background: #1CB0F6;
      color: #FFFFFF;
      font-size: 11px;
      font-weight: 800;
      padding: 3px 8px;
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

// Khi mở trên trình duyệt (hoặc các đường dẫn /docs, /swagger, /api-docs) -> Hiển thị Swagger UI
app.get(['/docs', '/swagger', '/api-docs'], (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(swaggerHtml);
});

// -------------------------------------------------------------
// Health & Info
// -------------------------------------------------------------
app.get(['/health', '/api/health'], (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    database: process.env.DATABASE_URL ? 'configured' : 'not_configured',
  });
});

// Trang chủ: Nếu là trình duyệt truy cập -> hiển thị Swagger UI tương tác, nếu là API client -> trả JSON
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

// Trang Chính sách quyền riêng tư (Privacy Policy) phục vụ Google OAuth
app.get('/privacy', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Chính sách bảo mật - English 12</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #2d3748; }
    h1 { color: #1a365d; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px; }
    h2 { color: #2b6cb0; margin-top: 24px; }
    p, li { font-size: 16px; }
  </style>
</head>
<body>
  <h1>Chính Sách Bảo Mật - Ứng Dụng English 12</h1>
  <p>Cập nhật lần cuối: Tháng 11/2026</p>
  
  <h2>1. Thu thập dữ liệu</h2>
  <p>Ứng dụng English 12 chỉ thu thập các thông tin tối thiểu cần thiết để cung cấp trải nghiệm học tập cá nhân hóa:</p>
  <ul>
    <li>Thông tin tài khoản: Tên hiển thị, địa chỉ email và ảnh đại diện (được cung cấp khi đăng ký hoặc đăng nhập thông qua Google Sign-In).</li>
    <li>Tiến độ học tập: Điểm số, lịch sử làm bài, từ vựng yêu thích và thống kê học tập nhằm mục đích lưu trữ và đồng bộ hóa bài học cho cá nhân người dùng.</li>
  </ul>

  <h2>2. Mục đích sử dụng dữ liệu</h2>
  <p>Dữ liệu chỉ được sử dụng cho các mục đích:</p>
  <ul>
    <li>Xác thực danh tính và duy trì phiên đăng nhập của người học.</li>
    <li>Lưu trữ kết quả ôn luyện và cá nhân hóa lộ trình học tiếng Anh 12.</li>
    <li>Không chia sẻ, mua bán hoặc tiết lộ thông tin người dùng cho bất kỳ bên thứ ba nào vì mục đích quảng cáo hay thương mại.</li>
  </ul>

  <h2>3. Quyền của người dùng</h2>
  <p>Người dùng có toàn quyền xem, chỉnh sửa thông tin cá nhân hoặc yêu cầu xóa tài khoản cùng toàn bộ dữ liệu học tập liên quan bất kỳ lúc nào trực tiếp trong ứng dụng.</p>

  <h2>4. Liên hệ</h2>
  <p>Mọi thắc mắc về chính sách bảo mật, vui lòng liên hệ qua email hỗ trợ của nhà phát triển ứng dụng.</p>
</body>
</html>`);
});

// Trang Điều khoản sử dụng (Terms of Service)
app.get('/terms', (req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Điều khoản sử dụng - English 12</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #2d3748; }
    h1 { color: #1a365d; border-bottom: 2px solid #e2e8f0; padding-bottom: 12px; }
    h2 { color: #2b6cb0; margin-top: 24px; }
  </style>
</head>
<body>
  <h1>Điều Khoản Sử Dụng - Ứng Dụng English 12</h1>
  <h2>1. Chấp thuận điều khoản</h2>
  <p>Bằng việc đăng ký tài khoản hoặc sử dụng ứng dụng English 12, bạn đồng ý tuân thủ các điều khoản này nhằm mục đích học tập và ôn luyện kiến thức Tiếng Anh lớp 12.</p>
  <h2>2. Quyền sở hữu trí tuệ</h2>
  <p>Toàn bộ tài liệu học tập, nội dung câu hỏi và giao diện ứng dụng được biên soạn phục vụ mục đích giáo dục cho học sinh trung học phổ thông.</p>
</body>
</html>`);
});

// -------------------------------------------------------------
// 2. Authentication: Register, Login, Google Auth, Forgot & Reset Password
// -------------------------------------------------------------

// Đăng ký tài khoản mới bằng Email & Mật khẩu
app.post('/api/auth/register', async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({
      error: 'Cơ sở dữ liệu máy chủ chưa được cấu hình (thiếu DATABASE_URL). Bạn có thể tiếp tục học thử với vai trò Khách.',
    });
  }

  let { email, password, displayName } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Vui lòng cung cấp email và mật khẩu.' });
  }

  email = String(email).trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Định dạng email không hợp lệ.' });
  }

  // KHÔNG trim mật khẩu theo đúng nguyên tắc bảo mật
  if (typeof password !== 'string' || password.length < 6) {
    return res.status(400).json({ error: 'Mật khẩu phải chứa từ 6 ký tự trở lên.' });
  }

  const name = (displayName && typeof displayName === 'string' && displayName.trim().length > 0)
    ? displayName.trim().slice(0, 120)
    : email.split('@')[0];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Kiểm tra trùng email (xử lý cả 2 request đồng thời qua try/catch unique constraint)
    const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Email này đã có tài khoản trên English 12. Bạn vui lòng bấm "Đăng nhập ngay" ở bên dưới hoặc dùng tính năng "Quên mật khẩu" nếu không nhớ mật khẩu nhé.',
      });
    }

    const userId = 'usr_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex');
    const { hash, salt } = hashPassword(password);
    const verificationToken = crypto.randomBytes(32).toString('hex');

    // Luôn luôn ép role = 'student' ở phía máy chủ
    await client.query(
      `INSERT INTO users (id, email, password_hash, password_salt, display_name, auth_provider, role, email_verified, verification_token)
       VALUES ($1, $2, $3, $4, $5, 'email', 'student', FALSE, $6)`,
      [userId, email, hash, salt, name, verificationToken]
    );

    // Tạo profile ban đầu: KHÔNG tự ý gán điểm thi hay ngày thi giả mạo
    await client.query(
      `INSERT INTO user_profiles (user_id, daily_minutes, reminder_enabled, current_streak, total_xp)
       VALUES ($1, 20, FALSE, 0, 0)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );

    await client.query('COMMIT');

    const token = generateToken({ id: userId, email, role: 'student' });

    // Gửi email xác minh nếu có cấu hình SMTP
    let emailSent = false;
    if (mailerTransporter) {
      try {
        const appUrl = process.env.APP_URL || 'https://english12-backend.onrender.com';
        const verifyUrl = `${appUrl}/api/auth/verify-email?token=${verificationToken}`;
        await mailerTransporter.sendMail({
          from: process.env.SMTP_FROM || process.env.SMTP_USER,
          to: email,
          subject: '[English 12] Xác minh địa chỉ email tài khoản học viên',
          html: `
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <h2>Chào mừng bạn đến với English 12!</h2>
              <p>Xin chào <strong>${name}</strong>,</p>
              <p>Cảm ơn bạn đã đăng ký tài khoản học viên. Vui lòng bấm vào liên kết bên dưới để xác minh địa chỉ email:</p>
              <p style="margin: 24px 0;">
                <a href="${verifyUrl}" style="background-color: #2563EB; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold;">Xác minh Email ngay</a>
              </p>
              <p style="color: #64748B; font-size: 13px;">Nếu bạn không tạo tài khoản này, vui lòng bỏ qua thư này.</p>
            </div>
          `,
        });
        emailSent = true;
      } catch (mailErr) {
        console.warn('⚠️ Lỗi gửi email xác minh:', mailErr.message);
      }
    }

    res.status(201).json({
      message: emailSent
        ? 'Đăng ký tài khoản thành công. Thư xác minh đã được gửi đến email của bạn.'
        : 'Tài khoản đã được tạo, chưa gửi được thư xác minh do máy chủ chưa kích hoạt SMTP. Bạn vẫn có thể tiếp tục học tập.',
      user: {
        id: userId,
        email,
        displayName: name,
        authProvider: 'email',
        role: 'student',
        emailVerified: false,
      },
      token,
      emailSent,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.code === '23505') {
      return res.status(409).json({
        error: 'Email này đã có tài khoản trên English 12. Bạn vui lòng bấm "Đăng nhập ngay" ở bên dưới hoặc dùng tính năng "Quên mật khẩu" nếu không nhớ mật khẩu nhé.',
      });
    }
    res.status(500).json({ error: 'Lỗi máy chủ khi đăng ký: ' + err.message });
  } finally {
    client.release();
  }
});

// Đăng nhập bằng Email & Mật khẩu thật
app.post('/api/auth/login', async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({
      error: 'Cơ sở dữ liệu máy chủ chưa được cấu hình. Bạn có thể tiếp tục trải nghiệm với vai trò Khách.',
    });
  }

  let { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Vui lòng cung cấp email và mật khẩu.' });
  }

  email = String(email).trim().toLowerCase();
  const rateLimitKey = `${req.ip}_${email}`;
  if (!checkLoginRateLimit(rateLimitKey)) {
    return res.status(429).json({
      error: 'Bạn đã thử đăng nhập sai quá nhiều lần. Vui lòng thử lại sau 15 phút hoặc sử dụng tính năng Quên mật khẩu.',
    });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không chính xác.' });
    }

    const user = result.rows[0];
    if (user.auth_provider === 'google' && !user.password_hash) {
      return res.status(400).json({
        error: 'Tài khoản này được đăng ký qua Google. Vui lòng chọn "Đăng nhập bằng Google".',
      });
    }

    const isValid = verifyPassword(password, user.password_hash, user.password_salt);
    if (!isValid) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không chính xác.' });
    }

    clearLoginRateLimit(rateLimitKey);

    const token = generateToken({
      id: user.id,
      email: user.email,
      role: user.role || 'student',
    });

    res.json({
      message: 'Đăng nhập thành công.',
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
        avatarUrl: user.avatar_url || '',
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

// Đăng nhập Google thật (Xác thực ID Token bằng google-auth-library chính thức)
app.post('/api/auth/google', async (req, res) => {
  const idToken = req.body?.idToken || req.body?.id_token;

  if (!idToken || typeof idToken !== 'string' || idToken.trim().length === 0) {
    return res.status(400).json({ error: 'Thiếu idToken xác thực từ Google.' });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }

  // Danh sách Audience (Web OAuth Client ID) được chấp nhận trên máy chủ
  const rawAudiences = process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '';
  const allowedAudiences = rawAudiences
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  // Không bỏ qua kiểm tra Audience nếu chưa cấu hình
  if (allowedAudiences.length === 0) {
    console.error('❌ [Google Auth] Máy chủ chưa cấu hình GOOGLE_CLIENT_ID để xác thực Audience.');
    return res.status(503).json({
      error: 'Dịch vụ Đăng nhập Google chưa sẵn sàng (Máy chủ chưa cấu hình GOOGLE_CLIENT_ID).',
    });
  }

  try {
    // Xác thực chữ ký số, issuer (accounts.google.com), expiration (exp) và audience (aud)
    let payload;
    try {
      const ticket = await googleOAuthClient.verifyIdToken({
        idToken,
        audience: allowedAudiences,
      });
      payload = ticket.getPayload();
    } catch (verifyErr) {
      console.warn('[Google Auth] Xác thực ID Token thất bại:', verifyErr.message);
      return res.status(401).json({
        error: 'Xác thực Google thất bại: Token không hợp lệ hoặc đã hết hạn (' + verifyErr.message + ').',
      });
    }

    if (!payload) {
      return res.status(401).json({ error: 'Không lấy được thông tin xác thực từ token Google.' });
    }

    // Định danh người dùng bằng trường sub (Subject ID duy nhất do Google cấp)
    const googleSub = payload.sub;
    const googleEmail = payload.email ? payload.email.trim().toLowerCase() : null;
    const emailVerified = payload.email_verified === true || payload.email_verified === 'true';
    const googleName =
      (payload.name && payload.name.trim()) ||
      (googleEmail ? googleEmail.split('@')[0] : 'Học sinh English 12');
    const googleAvatar = payload.picture || '';

    if (!googleSub) {
      return res.status(400).json({ error: 'Token Google thiếu định danh người dùng (sub).' });
    }
    if (!googleEmail) {
      return res.status(400).json({ error: 'Token Google thiếu địa chỉ email.' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // 1. Kiểm tra tài khoản đã liên kết trước đó theo google_id (sub)
      const existingByGoogle = await client.query(
        'SELECT * FROM users WHERE google_id = $1',
        [googleSub]
      );

      let userId;
      let userRole = 'student';

      if (existingByGoogle.rows.length > 0) {
        const user = existingByGoogle.rows[0];
        userId = user.id;
        userRole = user.role || 'student';

        // Cập nhật thông tin mới nhất từ Google (nếu có thay đổi)
        await client.query(
          `UPDATE users
           SET email = $1,
               avatar_url = COALESCE(NULLIF($2, ''), avatar_url),
               email_verified = $3,
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $4`,
          [googleEmail, googleAvatar, emailVerified, userId]
        );
      } else {
        // 2. Nếu chưa có theo google_id, kiểm tra xem email đã tồn tại chưa
        const existingByEmail = await client.query(
          'SELECT * FROM users WHERE email = $1',
          [googleEmail]
        );

        if (existingByEmail.rows.length > 0) {
          const existingUser = existingByEmail.rows[0];

          // Nếu email đã đăng ký bằng mật khẩu
          if (existingUser.auth_provider === 'email') {
            if (emailVerified) {
              // Email đã được Google chứng thực chính chủ -> Tự động liên kết Google ID để đăng nhập thuận tiện
              userId = existingUser.id;
              userRole = existingUser.role || 'student';
              await client.query(
                `UPDATE users
                 SET google_id = $1,
                     avatar_url = COALESCE(NULLIF($2, ''), avatar_url),
                     email_verified = TRUE,
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id = $3`,
                [googleSub, googleAvatar, userId]
              );
            } else {
              await client.query('ROLLBACK');
              return res.status(409).json({
                error: 'Email này đã có tài khoản mật khẩu trên hệ thống. Vui lòng đăng nhập bằng Email và Mật khẩu để bảo mật.',
              });
            }
          } else {
            // Nếu tài khoản cũ đã là google nhưng chưa lưu sub (từ các phiên bản trước)
            userId = existingUser.id;
            userRole = existingUser.role || 'student';
            await client.query(
              `UPDATE users
               SET google_id = $1,
                   avatar_url = COALESCE(NULLIF($2, ''), avatar_url),
                   email_verified = $3,
                   updated_at = CURRENT_TIMESTAMP
               WHERE id = $4`,
              [googleSub, googleAvatar, emailVerified, userId]
            );
          }
        } else {
          // 3. Tạo tài khoản học viên mới hoàn toàn
          userId = 'usr_g_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex');
          userRole = 'student'; // Backend quyết định role, tài khoản công khai luôn là student

          await client.query(
            `INSERT INTO users (id, google_id, email, display_name, avatar_url, auth_provider, role, email_verified)
             VALUES ($1, $2, $3, $4, $5, 'google', 'student', $6)`,
            [userId, googleSub, googleEmail, googleName, googleAvatar, emailVerified]
          );

          await client.query(
            `INSERT INTO user_profiles (user_id, daily_minutes, reminder_enabled, current_streak, total_xp)
             VALUES ($1, 20, FALSE, 0, 0)
             ON CONFLICT (user_id) DO NOTHING`,
            [userId]
          );
        }
      }

      await client.query('COMMIT');

      // Cấp JWT Token của hệ thống English 12 (không dùng ID Token Google làm session token vô thời hạn)
      const token = generateToken({ id: userId, email: googleEmail, role: userRole });

      // Không trả về hoặc log nguyên ID token
      res.json({
        message: 'Đăng nhập Google thành công.',
        user: {
          id: userId,
          email: googleEmail,
          displayName: googleName,
          avatarUrl: googleAvatar,
          authProvider: 'google',
          role: userRole,
          emailVerified,
        },
        token,
      });
    } catch (dbErr) {
      await client.query('ROLLBACK');
      throw dbErr;
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(500).json({ error: 'Lỗi máy chủ khi xử lý Google Sign-In: ' + err.message });
  }
});

// Lấy thông tin phiên hiện tại của học viên (Khôi phục phiên)
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }
  try {
    const result = await pool.query(
      'SELECT id, email, display_name, avatar_url, auth_provider, role, email_verified FROM users WHERE id = $1',
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Tài khoản không còn tồn tại hoặc đã bị thu hồi.' });
    }
    const user = result.rows[0];
    res.json({
      user: {
        id: user.id,
        email: user.email,
        displayName: user.display_name,
        avatarUrl: user.avatar_url || '',
        authProvider: user.auth_provider,
        role: user.role,
        emailVerified: user.email_verified || false,
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi xác thực: ' + err.message });
  }
});

// Quên mật khẩu & Gửi link đặt lại mật khẩu
app.post('/api/auth/forgot-password', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Vui lòng cung cấp địa chỉ email.' });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }

  const cleanEmail = String(email).trim().toLowerCase();
  try {
    const result = await pool.query('SELECT id, display_name FROM users WHERE email = $1', [cleanEmail]);

    // Phản hồi an toàn không tiết lộ email có tồn tại trong hệ thống hay không
    if (result.rows.length === 0) {
      return res.json({
        message: 'Nếu email tồn tại trong hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.',
      });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 phút

    await pool.query(
      'UPDATE users SET reset_password_token = $1, reset_password_expires = $2 WHERE id = $3',
      [resetToken, expiresAt, result.rows[0].id]
    );

    const appUrl = process.env.APP_URL || 'https://english12-backend.onrender.com';
    const resetUrl = `${appUrl}/reset-password?token=${resetToken}`;
    const studentName = result.rows[0].display_name || 'học viên';

    const emailSubject = '[English 12] Yêu cầu đặt lại mật khẩu tài khoản học viên';
    const emailHtml = `
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2>Yêu cầu đặt lại mật khẩu</h2>
        <p>Xin chào <strong>${studentName}</strong>,</p>
        <p>Hệ thống nhận được yêu cầu đặt lại mật khẩu cho tài khoản English 12 của bạn. Vui lòng bấm vào liên kết bên dưới để tạo mật khẩu mới:</p>
        <p style="margin: 24px 0;">
          <a href="${resetUrl}" style="background-color: #1CB0F6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">Đặt lại Mật khẩu</a>
        </p>
        <p style="color: #DC2626; font-size: 13px;">Liên kết này chỉ có hiệu lực trong vòng 15 phút và chỉ được sử dụng một lần.</p>
        <p style="color: #64748B; font-size: 13px;">Nếu bạn không yêu cầu hành động này, vui lòng bỏ qua thư này để bảo vệ tài khoản.</p>
      </div>
    `;

    let emailDelivered = false;

    // 1. Ưu tiên: Gửi qua Resend API (HTTPS Port 443 - Không bao giờ bị Render chặn)
    if (process.env.RESEND_API_KEY) {
      try {
        const resendRes = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${process.env.RESEND_API_KEY.trim()}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: process.env.RESEND_FROM || 'English 12 <onboarding@resend.dev>',
            to: [cleanEmail],
            subject: emailSubject,
            html: emailHtml,
          }),
        });
        if (resendRes.ok) {
          console.log(`✅ [Resend API] Đã gửi email đặt lại mật khẩu tới: ${cleanEmail}`);
          emailDelivered = true;
        } else {
          const errData = await resendRes.json();
          console.warn('⚠️ [Resend API] Lỗi gửi email:', errData);
        }
      } catch (resendErr) {
        console.warn('⚠️ [Resend API] Ngoại lệ kết nối:', resendErr.message);
      }
    }

    // 2. Dự phòng: Gửi qua Nodemailer SMTP
    if (!emailDelivered && mailerTransporter) {
      try {
        await mailerTransporter.sendMail({
          from: process.env.SMTP_FROM || process.env.SMTP_USER,
          to: cleanEmail,
          subject: emailSubject,
          html: emailHtml,
        });
        console.log(`✅ [SMTP] Đã gửi email đặt lại mật khẩu tới: ${cleanEmail}`);
        emailDelivered = true;
      } catch (smtpErr) {
        console.warn('⚠️ [SMTP] Máy chủ Render bị chặn kết nối SMTP:', smtpErr.message);
      }
    }

    // Trả kết quả thành công bảo mật (chỉ gửi token qua email, không để lộ trên API response)
    const responsePayload = {
      message: 'Nếu email tồn tại trong hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.',
      emailDelivered,
    };

    // Chỉ khi gửi email thất bại trong môi trường nội bộ mới trả resetToken làm cứu cánh dev
    if (!emailDelivered && process.env.NODE_ENV !== 'production') {
      responsePayload.resetToken = resetToken;
      responsePayload.resetUrl = resetUrl;
    }

    res.json(responsePayload);
  } catch (err) {
    res.status(500).json({ error: 'Lỗi xử lý yêu cầu đặt lại mật khẩu: ' + err.message });
  }
});

// Đặt lại mật khẩu mới bằng Token
app.post('/api/auth/reset-password', async (req, res) => {
  const { token, newPassword } = req.body;
  if (!token || !newPassword) {
    return res.status(400).json({ error: 'Vui lòng cung cấp mã xác nhận và mật khẩu mới.' });
  }

  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    return res.status(400).json({ error: 'Mật khẩu mới phải chứa từ 6 ký tự trở lên.' });
  }

  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }

  try {
    const result = await pool.query(
      'SELECT id FROM users WHERE reset_password_token = $1 AND reset_password_expires > NOW()',
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({
        error: 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng gửi lại yêu cầu mới.',
      });
    }

    const userId = result.rows[0].id;
    const { hash, salt } = hashPassword(newPassword);

    // Cập nhật mật khẩu mới và hủy token một lần
    await pool.query(
      `UPDATE users
       SET password_hash = $1, password_salt = $2, reset_password_token = NULL, reset_password_expires = NULL, updated_at = CURRENT_TIMESTAMP
       WHERE id = $3`,
      [hash, salt, userId]
    );

    res.json({ message: 'Đặt lại mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.' });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi cập nhật mật khẩu: ' + err.message });
  }
});

// Xác minh địa chỉ email qua link GET
app.get('/api/auth/verify-email', async (req, res) => {
  const { token } = req.query;
  if (!token) {
    return res.status(400).send('<h3>Thiếu mã xác minh email.</h3>');
  }

  if (!process.env.DATABASE_URL) {
    return res.status(503).send('<h3>Cơ sở dữ liệu máy chủ chưa sẵn sàng.</h3>');
  }

  try {
    const result = await pool.query(
      'SELECT id, display_name FROM users WHERE verification_token = $1',
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(400).send(`
        <div style="font-family: sans-serif; text-align: center; padding: 40px;">
          <h2 style="color: #DC2626;">Liên kết xác minh không hợp lệ hoặc đã được sử dụng</h2>
          <p>Vui lòng mở ứng dụng English 12 để gửi lại yêu cầu xác minh mới.</p>
        </div>
      `);
    }

    await pool.query(
      'UPDATE users SET email_verified = TRUE, verification_token = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $1',
      [result.rows[0].id]
    );

    res.send(`
      <div style="font-family: sans-serif; text-align: center; padding: 40px;">
        <h2 style="color: #16A34A;">✅ Xác minh Email thành công!</h2>
        <p>Tài khoản học viên <strong>${result.rows[0].display_name}</strong> đã được kích hoạt đầy đủ.</p>
        <p>Bạn có thể quay lại ứng dụng English 12 để tiếp tục hành trình luyện thi.</p>
      </div>
    `);
  } catch (err) {
    res.status(500).send('<h3>Lỗi hệ thống khi xác minh: ' + err.message + '</h3>');
  }
});

// Gửi lại email xác minh
app.post('/api/auth/resend-verification', authenticateToken, async (req, res) => {
  if (!mailerTransporter) {
    return res.status(503).json({
      error: 'Dịch vụ gửi thư điện tử chưa được cấu hình trên máy chủ.',
    });
  }

  try {
    const result = await pool.query('SELECT id, email, display_name, email_verified FROM users WHERE id = $1', [req.user.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Không tìm thấy người dùng.' });
    }
    const user = result.rows[0];
    if (user.email_verified) {
      return res.json({ message: 'Địa chỉ email này đã được xác minh trước đó.' });
    }

    const verificationToken = crypto.randomBytes(32).toString('hex');
    await pool.query('UPDATE users SET verification_token = $1 WHERE id = $2', [verificationToken, user.id]);

    const appUrl = process.env.APP_URL || 'https://english12-backend.onrender.com';
    const verifyUrl = `${appUrl}/api/auth/verify-email?token=${verificationToken}`;

    await mailerTransporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to: user.email,
      subject: '[English 12] Xác minh lại địa chỉ email tài khoản học viên',
      html: `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2>Xác minh lại địa chỉ Email</h2>
          <p>Xin chào <strong>${user.display_name}</strong>,</p>
          <p>Bạn đã yêu cầu gửi lại thư xác minh email cho tài khoản English 12. Vui lòng bấm liên kết bên dưới:</p>
          <p style="margin: 24px 0;">
            <a href="${verifyUrl}" style="background-color: #2563EB; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold;">Xác minh Email</a>
          </p>
        </div>
      `,
    });

    res.json({ message: 'Đã gửi lại thư xác minh đến email của bạn.' });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi gửi lại thư xác minh: ' + err.message });
  }
});

// Trang HTML cho phép người dùng đặt lại mật khẩu từ trình duyệt khi bấm link email (Chuẩn giao diện Duolingo)
app.get('/reset-password', (req, res) => {
  const token = req.query.token || '';
  res.send(`
    <!DOCTYPE html>
    <html lang="vi">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Đặt lại mật khẩu - English 12</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
          background: #131F24;
          color: #FFFFFF;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          padding: 20px;
        }
        .container {
          width: 100%;
          max-width: 400px;
          text-align: center;
        }
        .logo-title {
          font-size: 26px;
          font-weight: 800;
          color: #1CB0F6;
          margin-bottom: 24px;
          letter-spacing: -0.5px;
        }
        .card-title {
          font-size: 24px;
          font-weight: 700;
          margin-bottom: 24px;
          color: #FFFFFF;
        }
        .form-group {
          margin-bottom: 16px;
          text-align: left;
          position: relative;
        }
        .input-wrap {
          position: relative;
          display: flex;
          align-items: center;
        }
        input {
          width: 100%;
          background: #202F36;
          border: 2px solid #37464F;
          border-radius: 14px;
          padding: 14px 44px 14px 16px;
          color: #FFFFFF;
          font-size: 15px;
          outline: none;
          transition: border-color 0.2s;
        }
        input:focus {
          border-color: #1CB0F6;
        }
        input::placeholder {
          color: #778D97;
        }
        .toggle-btn {
          position: absolute;
          right: 14px;
          background: none;
          border: none;
          cursor: pointer;
          color: #778D97;
          display: flex;
          align-items: center;
          padding: 0;
        }
        .toggle-btn:hover {
          color: #FFFFFF;
        }
        .btn-submit {
          width: 100%;
          background: #1CB0F6;
          color: #FFFFFF;
          border: none;
          border-radius: 14px;
          padding: 14px;
          font-size: 16px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          cursor: pointer;
          margin-top: 10px;
          box-shadow: 0 4px 0 #1899D6;
          transition: transform 0.1s, box-shadow 0.1s;
        }
        .btn-submit:active {
          transform: translateY(2px);
          box-shadow: 0 2px 0 #1899D6;
        }
        .msg {
          padding: 14px;
          border-radius: 12px;
          margin-top: 18px;
          font-size: 14px;
          line-height: 1.45;
          display: none;
        }
        .success {
          background: #193B2D;
          border: 1px solid #58CC02;
          color: #79F73A;
        }
        .error {
          background: #3B1B1B;
          border: 1px solid #EA2B2B;
          color: #FF7878;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="logo-title">English 12</div>
        <h1 class="card-title">Đặt lại mật khẩu</h1>
        
        <form id="resetForm">
          <div class="form-group">
            <div class="input-wrap">
              <input type="password" id="newPass" minlength="6" required placeholder="Mật khẩu mới" />
              <button type="button" class="toggle-btn" onclick="togglePass('newPass', this)" title="Ẩn/Hiện">
                <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
              </button>
            </div>
          </div>

          <div class="form-group">
            <div class="input-wrap">
              <input type="password" id="confirmPass" minlength="6" required placeholder="Xác nhận mật khẩu mới" />
              <button type="button" class="toggle-btn" onclick="togglePass('confirmPass', this)" title="Ẩn/Hiện">
                <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
              </button>
            </div>
          </div>

          <button type="submit" class="btn-submit" id="btnSubmit">GỬI</button>
        </form>

        <div id="statusMsg" class="msg"></div>
      </div>

      <script>
        function togglePass(inputId, btn) {
          const input = document.getElementById(inputId);
          if (input.type === 'password') {
            input.type = 'text';
            btn.style.color = '#1CB0F6';
          } else {
            input.type = 'password';
            btn.style.color = '#778D97';
          }
        }

        const form = document.getElementById('resetForm');
        const statusMsg = document.getElementById('statusMsg');
        const token = '${token}';

        if (!token) {
          statusMsg.className = 'msg error';
          statusMsg.innerText = 'Đường dẫn không hợp lệ hoặc thiếu mã xác thực token.';
          statusMsg.style.display = 'block';
          form.style.display = 'none';
        }

        form.onsubmit = async (e) => {
          e.preventDefault();
          const pass = document.getElementById('newPass').value;
          const confirm = document.getElementById('confirmPass').value;

          if (pass.length < 6) {
            statusMsg.className = 'msg error';
            statusMsg.innerText = 'Mật khẩu phải có tối thiểu 6 ký tự.';
            statusMsg.style.display = 'block';
            return;
          }

          if (pass !== confirm) {
            statusMsg.className = 'msg error';
            statusMsg.innerText = 'Mật khẩu xác nhận không khớp. Vui lòng kiểm tra lại.';
            statusMsg.style.display = 'block';
            return;
          }

          const btn = document.getElementById('btnSubmit');
          btn.disabled = true;
          btn.innerText = 'ĐANG XỬ LÝ...';
          statusMsg.style.display = 'none';

          try {
            const res = await fetch('/api/auth/reset-password', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ token: token, newPassword: pass })
            });
            const data = await res.json();
            if (res.ok) {
              statusMsg.className = 'msg success';
              statusMsg.innerHTML = '<strong>' + data.message + '</strong><br><br>Bây giờ bạn có thể mở lại ứng dụng <strong>English 12</strong> trên điện thoại để đăng nhập bằng mật khẩu mới!';
              statusMsg.style.display = 'block';
              form.style.display = 'none';
            } else {
              statusMsg.className = 'msg error';
              statusMsg.innerText = data.error || 'Có lỗi xảy ra khi cập nhật mật khẩu.';
              statusMsg.style.display = 'block';
              btn.disabled = false;
              btn.innerText = 'GỬI';
            }
          } catch(err) {
            statusMsg.className = 'msg error';
            statusMsg.innerText = 'Không thể kết nối tới máy chủ. Vui lòng thử lại sau.';
            statusMsg.style.display = 'block';
            btn.disabled = false;
            btn.innerText = 'GỬI';
          }
        };
      </script>
    </body>
    </html>
  `);
});

// -------------------------------------------------------------
// 3. User Profile & Study Plan
// -------------------------------------------------------------
app.get('/api/profile', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }

  try {
    const userId = req.user.id;
    const result = await pool.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
    if (result.rows.length === 0) {
      return res.json({ targetScore: null, dailyMinutes: 20 });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/profile', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }

  try {
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
      [userId, targetScore || null, examDate || null, dailyMinutes || 20, reminderEnabled === true, Array.isArray(favoriteTopics) ? favoriteTopics.join(',') : '']
    );

    res.json({ message: 'Cập nhật lộ trình học thành công.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 4. Daily Stats & Streak Sync
// -------------------------------------------------------------
app.get('/api/stats/daily', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }
  try {
    const userId = req.user.id;
    const result = await pool.query('SELECT * FROM daily_stats WHERE user_id = $1 ORDER BY stat_date DESC LIMIT 30', [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/stats/daily', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }
  try {
    const userId = req.user.id;
    const { statDate, questionsDone, correctCount, xpEarned } = req.body;

    await pool.query(
      `INSERT INTO daily_stats (user_id, stat_date, questions_done, correct_count, xp_earned)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, stat_date) DO UPDATE SET
          questions_done = GREATEST(daily_stats.questions_done, EXCLUDED.questions_done),
          correct_count = GREATEST(daily_stats.correct_count, EXCLUDED.correct_count),
          xp_earned = GREATEST(daily_stats.xp_earned, EXCLUDED.xp_earned)`,
      [userId, statDate || new Date().toISOString().split('T')[0], questionsDone || 0, correctCount || 0, xpEarned || 0]
    );

    res.json({ message: 'Đồng bộ thống kê thành công.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// -------------------------------------------------------------
// 5. Exam Attempts
// -------------------------------------------------------------
app.post('/api/exams/submit', authenticateToken, async (req, res) => {
  if (!process.env.DATABASE_URL) {
    return res.status(503).json({ error: 'Cơ sở dữ liệu máy chủ chưa sẵn sàng.' });
  }
  try {
    const userId = req.user.id;
    const { examType, totalQuestions, correctCount, score, durationSeconds } = req.body;

    if (!totalQuestions || typeof totalQuestions !== 'number' || totalQuestions <= 0) {
      return res.status(400).json({ error: 'Số lượng câu hỏi bài thi không hợp lệ (phải lớn hơn 0).' });
    }
    if (correctCount === undefined || typeof correctCount !== 'number' || correctCount < 0 || correctCount > totalQuestions) {
      return res.status(400).json({ error: 'Số câu đúng không hợp lệ.' });
    }

    const attemptId = 'atm_' + Date.now();

    await pool.query(
      `INSERT INTO exam_attempts (id, user_id, exam_type, total_questions, correct_count, score, duration_seconds)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [attemptId, userId, examType || 'mock_thpt', totalQuestions, correctCount, score || 0.0, durationSeconds || 0]
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

// -------------------------------------------------------------
// 6. AI Tutor Assistant
// -------------------------------------------------------------
app.post('/api/ai/ask', authenticateToken, async (req, res) => {
  const { question, unitNumber, section, contextText } = req.body;
  if (!question || typeof question !== 'string' || question.trim().length === 0) {
    return res.status(400).json({ error: 'Nội dung câu hỏi không được để trống.' });
  }

  // Giới hạn độ dài yêu cầu để phòng chống lạm dụng
  if (question.length > 1000) {
    return res.status(400).json({ error: 'Câu hỏi quá dài (tối đa 1000 ký tự).' });
  }

  const aiApiKey = process.env.GEMINI_API_KEY || process.env.AI_API_KEY;
  if (!aiApiKey) {
    return res.status(503).json({
      isAvailable: false,
      error: 'Dịch vụ Trợ lý AI trực tuyến chưa cấu hình API Key trên máy chủ (Cần cung cấp GEMINI_API_KEY).',
      suggestion: 'Ứng dụng chuyển sang chế độ giải đáp từ điển & kiến thức trọng tâm SGK 12 ngoại tuyến.',
    });
  }

  try {
    // Gọi Google Generative Language API
    const aiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${aiApiKey}`;
    const aiRes = await fetch(aiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        system_instruction: {
          parts: [{
            text: `Bạn là Gia sư Tiếng Anh 12 Global Success (Việt Nam). Hỗ trợ học sinh học từ vựng, ngữ pháp, phương pháp làm bài theo chương trình SGK 12.
- Trả lời bằng tiếng Việt, ngắn gọn, súc tích, dễ hiểu.
- Gợi ý cách tư duy và giải thích nguyên tắc, không giải hộ hoặc đưa đáp án ngay nếu là câu hỏi trắc nghiệm chưa làm.
- Căn cứ vào Unit ${unitNumber || 'chung'} (${section || ''}).`
          }]
        },
        contents: [{
          parts: [{ text: `Ngữ cảnh: ${contextText || 'Bài học Tiếng Anh 12'}\n\nCâu hỏi: ${question}` }]
        }]
      })
    });

    if (!aiRes.ok) {
      const errData = await aiRes.json();
      return res.status(502).json({
        isAvailable: false,
        error: `Máy chủ AI trả về lỗi: ${errData?.error?.message || aiRes.statusText}`,
      });
    }

    const data = await aiRes.json();
    const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text || 'Chưa nhận được phản hồi phù hợp từ AI.';
    res.json({
      isAvailable: true,
      answer: reply,
      unitNumber,
      section,
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi máy chủ khi kết nối AI: ' + err.message });
  }
});

// Khởi chạy server
app.listen(port, async () => {
  console.log(`🚀 English 12 Backend API đang chạy tại cổng http://localhost:${port}`);
  await initializeDatabase();
});

module.exports = app;
