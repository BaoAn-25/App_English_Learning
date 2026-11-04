const crypto = require('crypto');

/**
 * Khởi tạo các bảng mở rộng cho RBAC (Teacher & Admin), Giám sát phòng thi 10s,
 * Quản lý phiên bản Sách giáo khoa (Curriculum Versioning) và Cấu hình AI Chatbot.
 */
async function initRbacAndProctoringTables(client) {
  await client.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_reason TEXT;
    UPDATE users SET role = 'admin' WHERE LOWER(TRIM(email)) = 'tongan542@gmail.com';

    CREATE TABLE IF NOT EXISTS system_configs (
      key VARCHAR(64) PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS system_audit_logs (
      id SERIAL PRIMARY KEY,
      actor_id VARCHAR(64),
      actor_email VARCHAR(255),
      actor_role VARCHAR(32),
      action VARCHAR(64) NOT NULL,
      target_type VARCHAR(64),
      target_id VARCHAR(128),
      details JSONB DEFAULT '{}'::jsonb,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS teacher_questions (
      id VARCHAR(64) PRIMARY KEY,
      grade INT NOT NULL DEFAULT 12,
      unit_number INT NOT NULL DEFAULT 1,
      skill VARCHAR(32) NOT NULL DEFAULT 'grammar',
      difficulty INT NOT NULL DEFAULT 2,
      stem TEXT NOT NULL,
      options_json JSONB NOT NULL DEFAULT '[]'::jsonb,
      correct_index INT NOT NULL DEFAULT 0,
      explanation TEXT NOT NULL DEFAULT '',
      created_by VARCHAR(64),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS teacher_materials (
      id VARCHAR(64) PRIMARY KEY,
      unit_number INT NOT NULL DEFAULT 1,
      category VARCHAR(32) NOT NULL DEFAULT 'reading',
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      vocabulary_json JSONB NOT NULL DEFAULT '[]'::jsonb,
      created_by VARCHAR(64),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS supervised_exams (
      id VARCHAR(64) PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      duration_minutes INT NOT NULL DEFAULT 45,
      deadline_at TIMESTAMP WITH TIME ZONE,
      grace_seconds INT NOT NULL DEFAULT 10,
      max_violations INT NOT NULL DEFAULT 2,
      violation_action VARCHAR(32) NOT NULL DEFAULT 'force_submit',
      questions_json JSONB NOT NULL DEFAULT '[]'::jsonb,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_by VARCHAR(64),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS exam_live_sessions (
      id VARCHAR(64) PRIMARY KEY,
      exam_id VARCHAR(64) REFERENCES supervised_exams(id) ON DELETE CASCADE,
      user_id VARCHAR(64),
      student_name VARCHAR(120),
      student_email VARCHAR(255),
      status VARCHAR(32) NOT NULL DEFAULT 'in_progress',
      violation_count INT NOT NULL DEFAULT 0,
      violation_logs JSONB NOT NULL DEFAULT '[]'::jsonb,
      teacher_warning_message TEXT,
      answered_count INT NOT NULL DEFAULT 0,
      total_questions INT NOT NULL DEFAULT 0,
      current_answers JSONB NOT NULL DEFAULT '{}'::jsonb,
      score NUMERIC(5, 2) NOT NULL DEFAULT 0.0,
      ai_feedback TEXT,
      started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      submitted_at TIMESTAMP WITH TIME ZONE,
      last_heartbeat_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS curriculum_sets (
      id VARCHAR(64) PRIMARY KEY,
      version_code VARCHAR(32) NOT NULL,
      title TEXT NOT NULL,
      description TEXT DEFAULT '',
      is_active BOOLEAN NOT NULL DEFAULT FALSE,
      payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_by VARCHAR(64),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    ALTER TABLE supervised_exams ADD COLUMN IF NOT EXISTS class_id VARCHAR(64);
    ALTER TABLE supervised_exams ADD COLUMN IF NOT EXISTS open_at TIMESTAMP WITH TIME ZONE;
    ALTER TABLE supervised_exams ADD COLUMN IF NOT EXISTS max_attempts INT NOT NULL DEFAULT 1;
    ALTER TABLE supervised_exams ADD COLUMN IF NOT EXISTS shuffle_questions BOOLEAN NOT NULL DEFAULT TRUE;

    ALTER TABLE exam_live_sessions ADD COLUMN IF NOT EXISTS student_explanation TEXT;
    ALTER TABLE exam_live_sessions ADD COLUMN IF NOT EXISTS explanation_submitted_at TIMESTAMP WITH TIME ZONE;

    CREATE TABLE IF NOT EXISTS classes (
      id VARCHAR(64) PRIMARY KEY,
      name VARCHAR(120) NOT NULL,
      school_name VARCHAR(255) DEFAULT '',
      academic_year VARCHAR(32) DEFAULT '2025-2026',
      join_code VARCHAR(32) UNIQUE NOT NULL,
      teacher_id VARCHAR(64),
      teacher_name VARCHAR(120) DEFAULT '',
      teacher_email VARCHAR(255) DEFAULT '',
      require_approval BOOLEAN NOT NULL DEFAULT FALSE,
      show_leaderboard BOOLEAN NOT NULL DEFAULT TRUE,
      allow_join BOOLEAN NOT NULL DEFAULT TRUE,
      is_archived BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS class_members (
      id VARCHAR(64) PRIMARY KEY,
      class_id VARCHAR(64) REFERENCES classes(id) ON DELETE CASCADE,
      student_id VARCHAR(64) NOT NULL,
      student_name VARCHAR(120) DEFAULT '',
      student_email VARCHAR(255) DEFAULT '',
      status VARCHAR(32) NOT NULL DEFAULT 'active',
      joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(class_id, student_id)
    );

    CREATE TABLE IF NOT EXISTS class_assignments (
      id VARCHAR(64) PRIMARY KEY,
      class_id VARCHAR(64) REFERENCES classes(id) ON DELETE CASCADE,
      class_name VARCHAR(120) DEFAULT '',
      title TEXT NOT NULL,
      assignment_type VARCHAR(32) NOT NULL DEFAULT 'unit_practice',
      unit_number INT NOT NULL DEFAULT 1,
      skills_json JSONB NOT NULL DEFAULT '["reading"]'::jsonb,
      exam_id VARCHAR(64),
      deadline_at TIMESTAMP WITH TIME ZONE,
      max_attempts INT NOT NULL DEFAULT 2,
      show_answers_mode VARCHAR(32) NOT NULL DEFAULT 'after_submit',
      status VARCHAR(32) NOT NULL DEFAULT 'open',
      created_by VARCHAR(64),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS assignment_submissions (
      id VARCHAR(64) PRIMARY KEY,
      assignment_id VARCHAR(64) REFERENCES class_assignments(id) ON DELETE CASCADE,
      class_id VARCHAR(64),
      student_id VARCHAR(64) NOT NULL,
      student_name VARCHAR(120) DEFAULT '',
      student_email VARCHAR(255) DEFAULT '',
      score NUMERIC(5, 2) NOT NULL DEFAULT 0.0,
      correct_count INT NOT NULL DEFAULT 0,
      total_questions INT NOT NULL DEFAULT 0,
      skill_breakdown_json JSONB NOT NULL DEFAULT '{}'::jsonb,
      is_late BOOLEAN NOT NULL DEFAULT FALSE,
      submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS textbook_progress (
      id SERIAL PRIMARY KEY,
      user_id VARCHAR(64) NOT NULL,
      user_email VARCHAR(255) DEFAULT '',
      unit_number INT NOT NULL,
      section_name VARCHAR(64) NOT NULL,
      status VARCHAR(32) DEFAULT 'completed',
      score INT DEFAULT 100,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT unique_user_unit_section UNIQUE (user_id, unit_number, section_name)
    );

    CREATE TABLE IF NOT EXISTS question_bug_reports (
      id VARCHAR(64) PRIMARY KEY,
      question_id VARCHAR(64),
      unit_number INT NOT NULL DEFAULT 1,
      skill VARCHAR(32) DEFAULT 'reading',
      title TEXT NOT NULL,
      details TEXT DEFAULT '',
      category VARCHAR(32) DEFAULT 'wrong_answer',
      status VARCHAR(32) NOT NULL DEFAULT 'new',
      reporter_id VARCHAR(64),
      reported_by VARCHAR(120) DEFAULT '',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS system_announcements (
      id VARCHAR(64) PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      target VARCHAR(32) NOT NULL DEFAULT 'all',
      type VARCHAR(32) NOT NULL DEFAULT 'general',
      class_id VARCHAR(64),
      sent_by VARCHAR(64),
      sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS teacher_requests (
      id VARCHAR(64) PRIMARY KEY,
      user_id VARCHAR(64),
      name VARCHAR(120) NOT NULL,
      email VARCHAR(255) NOT NULL,
      school VARCHAR(255) DEFAULT '',
      subject VARCHAR(120) DEFAULT 'Tiếng Anh 12',
      is_verified_domain BOOLEAN NOT NULL DEFAULT FALSE,
      status VARCHAR(32) NOT NULL DEFAULT 'pending',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);
}

async function logAudit(pool, actor, action, targetType, targetId, details = {}) {
  if (!process.env.DATABASE_URL) return;
  try {
    await pool.query(
      `INSERT INTO system_audit_logs (actor_id, actor_email, actor_role, action, target_type, target_id, details)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        actor?.id || 'system',
        actor?.email || 'system',
        actor?.role || 'system',
        action,
        targetType,
        String(targetId || ''),
        JSON.stringify(details || {}),
      ]
    );
  } catch (err) {
    console.warn('⚠️ Không thể ghi audit log:', err.message);
  }
}

async function getActiveAiConfig(pool) {
  let dbKey = '';
  let dbModel = '';
  let dbProvider = 'gemini';
  if (process.env.DATABASE_URL) {
    try {
      const res = await pool.query(
        `SELECT key, value FROM system_configs WHERE key IN ('ai_api_key', 'ai_model', 'ai_provider')`
      );
      for (const row of res.rows) {
        if (row.key === 'ai_api_key') dbKey = (row.value || '').trim();
        if (row.key === 'ai_model') dbModel = (row.value || '').trim();
        if (row.key === 'ai_provider') dbProvider = (row.value || 'gemini').trim();
      }
    } catch (_) {}
  }
  const apiKey = dbKey || process.env.GEMINI_API_KEY || process.env.AI_API_KEY || '';
  const model = dbModel || process.env.GEMINI_MODEL || 'gemini-2.5-flash';
  return {
    provider: dbProvider || 'gemini',
    apiKey: apiKey.trim(),
    model: model.trim(),
    source: dbKey ? 'database_admin_config' : (apiKey ? 'environment_variable' : 'unconfigured'),
  };
}

async function callGeminiWithFallback({
  apiKey,
  preferredModel,
  systemInstruction,
  userPrompt,
  imageBase64,
  mimeType,
}) {
  if (!apiKey) {
    return { ok: false, error: 'Chưa cấu hình khóa API Key cho AI.' };
  }

  const modelsToTry = Array.from(
    new Set([
      preferredModel || 'gemini-2.5-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ])
  );

  const userParts = [{ text: userPrompt }];
  if (imageBase64 && typeof imageBase64 === 'string' && imageBase64.trim().length > 0) {
    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '').trim();
    userParts.push({
      inline_data: {
        mime_type: mimeType || 'image/jpeg',
        data: cleanBase64,
      },
    });
  }

  let lastError = 'Không thể kết nối tới dịch vụ AI.';
  for (const modelName of modelsToTry) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          system_instruction: systemInstruction
            ? { parts: [{ text: systemInstruction }] }
            : undefined,
          contents: [{ parts: userParts }],
        }),
      });

      if (res.ok) {
        const data = await res.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
        if (text) {
          return { ok: true, text, modelUsed: modelName };
        }
      } else {
        const errData = await res.json().catch(() => ({}));
        lastError = errData?.error?.message || `HTTP ${res.status}`;
      }
    } catch (err) {
      lastError = err.message;
    }
  }

  return { ok: false, error: lastError };
}

/**
 * Kiểm tra xem học viên có đang ở trong Phòng thi có giám sát hay không.
 * Nếu có -> Khóa toàn bộ AI Chatbot & Dịch thuật để chống gian lận.
 */
async function checkStudentExamLock(pool, userId) {
  if (!process.env.DATABASE_URL || !userId) return null;
  try {
    const res = await pool.query(
      `SELECT s.id, s.exam_id, e.title
       FROM exam_live_sessions s
       JOIN supervised_exams e ON e.id = s.exam_id
       WHERE s.user_id = $1 AND s.status IN ('in_progress', 'warning_out_of_app')
       ORDER BY s.started_at DESC LIMIT 1`,
      [userId]
    );
    if (res.rows.length > 0) {
      return res.rows[0];
    }
  } catch (_) {}
  return null;
}

/**
 * Tính điểm bài thi dựa trên danh sách câu hỏi và đáp án hiện tại của học sinh
 */
function calculateSupervisedExamScore(questionsJson, currentAnswersMap) {
  const questions = Array.isArray(questionsJson) ? questionsJson : [];
  if (questions.length === 0) {
    return { correctCount: 0, totalQuestions: 0, score: 0.0 };
  }
  const answers = currentAnswersMap && typeof currentAnswersMap === 'object' ? currentAnswersMap : {};
  let correctCount = 0;
  questions.forEach((q, idx) => {
    const qId = String(q.id || idx);
    const chosen = answers[qId] !== undefined ? Number(answers[qId]) : (answers[String(idx)] !== undefined ? Number(answers[String(idx)]) : -1);
    const correctIdx = Number(q.correctIndex ?? q.correct_index ?? 0);
    if (chosen === correctIdx) {
      correctCount += 1;
    }
  });
  const score = Number(((correctCount / questions.length) * 10).toFixed(2));
  return { correctCount, totalQuestions: questions.length, score };
}

function registerRbacProctorAiRoutes(app, pool, { authenticateToken, hashPassword }) {
  // Middleware lấy thông tin user mới nhất từ DB (kiểm tra cả trạng thái bị khóa is_locked và role thực tế)
  async function attachFreshUser(req, res, next) {
    if (!process.env.DATABASE_URL) {
      return next();
    }
    try {
      const result = await pool.query(
        'SELECT id, email, display_name, role, is_locked, locked_reason FROM users WHERE id = $1',
        [req.user.id]
      );
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Tài khoản không tồn tại hoặc đã bị xóa khỏi hệ thống.' });
      }
      const dbUser = result.rows[0];
      if (dbUser.email && dbUser.email.toLowerCase().trim() === 'tongan542@gmail.com') dbUser.role = 'admin';
      if (dbUser.is_locked) {
        return res.status(403).json({
          error: `Tài khoản của bạn đã bị khóa bởi Quản trị viên. Lý do: ${dbUser.locked_reason || 'Vi phạm quy định hệ thống.'}`,
          isLocked: true,
          lockedReason: dbUser.locked_reason || 'Vi phạm quy định hệ thống.',
        });
      }
      req.user = {
        ...req.user,
        id: dbUser.id,
        email: dbUser.email,
        displayName: dbUser.display_name,
        role: dbUser.role || 'student',
      };
      next();
    } catch (err) {
      res.status(500).json({ error: 'Lỗi xác thực quyền người dùng: ' + err.message });
    }
  }

  function requireRoles(allowedRoles) {
    return [
      authenticateToken,
      attachFreshUser,
      (req, res, next) => {
        const userRole = req.user?.role || 'student';
        if (!allowedRoles.includes(userRole)) {
          return res.status(403).json({
            error: `Quyền truy cập bị từ chối. Chức năng này yêu cầu vai trò: ${allowedRoles.join(' hoặc ')}. Vai trò hiện tại của bạn: ${userRole}.`,
          });
        }
        next();
      },
    ];
  }

  // ---------------------------------------------------------------------------
  // 1. Chuyển đổi vai trò nhanh phục vụ Kiểm thử / Khởi tạo Admin & Giáo viên
  // ---------------------------------------------------------------------------
  app.post('/api/auth/switch-role', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu chưa sẵn sàng.' });
    }
    const { targetRole } = req.body;
    const validRoles = ['student', 'teacher', 'admin'];
    if (!validRoles.includes(targetRole)) {
      return res.status(400).json({ error: 'Vai trò không hợp lệ (chỉ chấp nhận student, teacher, admin).' });
    }

    try {
      await pool.query(
        'UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
        [targetRole, req.user.id]
      );
      await logAudit(pool, req.user, 'SWITCH_ROLE', 'user', req.user.id, {
        fromRole: req.user.role,
        toRole: targetRole,
      });
      res.json({
        message: `Đã chuyển vai trò tài khoản sang "${targetRole.toUpperCase()}" thành công.`,
        role: targetRole,
      });
    } catch (err) {
      res.status(500).json({ error: 'Không thể cập nhật vai trò: ' + err.message });
    }
  });

  // ---------------------------------------------------------------------------
  // 2. Cấu hình AI & Trợ lý Cá nhân AI Chatbot Đa Vai Trò (Student / Teacher / Admin)
  // ---------------------------------------------------------------------------
  app.get('/api/admin/ai-config', requireRoles(['admin', 'teacher']), async (req, res) => {
    const config = await getActiveAiConfig(pool);
    const maskedKey = config.apiKey
      ? config.apiKey.slice(0, 6) + '••••••••••••••••' + config.apiKey.slice(-4)
      : '';
    res.json({
      provider: config.provider,
      model: config.model,
      hasApiKey: Boolean(config.apiKey),
      maskedApiKey: maskedKey,
      source: config.source,
    });
  });

  app.put('/api/admin/ai-config', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) {
      return res.status(503).json({ error: 'Cơ sở dữ liệu chưa sẵn sàng.' });
    }
    const { apiKey, model, provider, testConnection } = req.body;
    try {
      if (apiKey !== undefined && String(apiKey).trim().length > 0) {
        await pool.query(
          `INSERT INTO system_configs (key, value, updated_at)
           VALUES ('ai_api_key', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
          [String(apiKey).trim()]
        );
      }
      if (model !== undefined && String(model).trim().length > 0) {
        await pool.query(
          `INSERT INTO system_configs (key, value, updated_at)
           VALUES ('ai_model', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
          [String(model).trim()]
        );
      }
      if (provider !== undefined && String(provider).trim().length > 0) {
        await pool.query(
          `INSERT INTO system_configs (key, value, updated_at)
           VALUES ('ai_provider', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
          [String(provider).trim()]
        );
      }

      const activeConfig = await getActiveAiConfig(pool);
      let connectionVerified = false;
      let testReply = '';

      if (testConnection && activeConfig.apiKey) {
        const testRes = await callGeminiWithFallback({
          apiKey: activeConfig.apiKey,
          preferredModel: activeConfig.model,
          systemInstruction: 'Trả lời ngắn gọn bằng 1 câu tiếng Việt.',
          userPrompt: 'Xin chào, kiểm tra kết nối hệ thống EngPass AI.',
        });
        connectionVerified = testRes.ok;
        testReply = testRes.ok ? testRes.text : testRes.error;
      }

      await logAudit(pool, req.user, 'UPDATE_AI_CONFIG', 'system_config', 'ai_config', {
        model: activeConfig.model,
        provider: activeConfig.provider,
        connectionVerified,
      });

      res.json({
        message: 'Đã lưu cấu hình AI Chatbot thành công.',
        model: activeConfig.model,
        provider: activeConfig.provider,
        hasApiKey: Boolean(activeConfig.apiKey),
        connectionVerified,
        testReply,
      });
    } catch (err) {
      res.status(500).json({ error: 'Lỗi lưu cấu hình AI: ' + err.message });
    }
  });

  // Trợ lý AI Cá nhân đa vai trò (Học viên, Giáo viên, Admin)
  app.post('/api/ai/chat', authenticateToken, attachFreshUser, async (req, res) => {
    const { message, roleContext, mode, unitNumber, contextText } = req.body;
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Vui lòng nhập nội dung yêu cầu cho Trợ lý AI.' });
    }

    const userRole = req.user.role || 'student';

    // RÀNG BUỘC 1: Khóa tuyệt đối AI khi học viên đang trong Phòng thi có giám sát
    if (userRole === 'student') {
      const activeExam = await checkStudentExamLock(pool, req.user.id);
      if (activeExam) {
        return res.status(403).json({
          examLocked: true,
          error: `🔒 Tính năng Trợ lý AI đang bị khóa tạm thời vì bạn đang làm bài thi có giám sát: "${activeExam.title}". Vui lòng hoàn thành và nộp bài thi trước!`,
        });
      }
    }

    const aiConfig = await getActiveAiConfig(pool);

    // Xây dựng System Prompt & Ràng buộc riêng cho từng vai trò
    let systemInstruction = '';
    if (userRole === 'admin' || roleContext === 'admin') {
      systemInstruction = `Bạn là Trợ lý Quản trị Hệ thống & Số hóa Học liệu (Admin AI Copilot) của nền tảng EngPass Tiếng Anh 12.
Nhiệm vụ của bạn:
1. Hỗ trợ Admin biên tập, chuẩn hóa nội dung bài học SGK mới (tách bài đọc, từ vựng kèm IPA, ngữ pháp, câu hỏi).
2. Phân tích chất lượng dữ liệu học tập và tóm tắt nhật ký hệ thống (Audit Logs).
RÀNG BUỘC BẮT BUỘC:
- Mọi dữ liệu sinh ra chỉ ở trạng thái Bản nháp (Preview) để Admin kiểm duyệt trước khi áp dụng.
- Không bao giờ tự ý thực thi lệnh xóa người dùng hay ghi đè cơ sở dữ liệu khi chưa có xác nhận của Admin.`;
    } else if (userRole === 'teacher' || roleContext === 'teacher') {
      systemInstruction = `Bạn là Trợ lý Soạn giảng & Chấm bài (Teacher AI Copilot) dành cho Giáo viên Tiếng Anh 12 THPT.
Nhiệm vụ của bạn:
1. Tự động biên soạn câu hỏi trắc nghiệm (4 đáp án A, B, C, D kèm lời giải thích chi tiết) theo đúng ma trận đề thi tốt nghiệp THPT và SGK Global Success 12.
2. Hỗ trợ chấm bài viết, phân tích lỗi sai phổ biến của học sinh và gợi ý nhận xét sư phạm.
3. Soạn tài liệu bổ trợ, tóm tắt ngữ pháp và từ vựng cho lớp học.
RÀNG BUỘC BẮT BUỘC:
- Nội dung sinh ra phải chính xác về học thuật, rõ ràng để Giáo viên duyệt và lưu vào Ngân hàng câu hỏi chỉ với 1 chạm.`;
    } else {
      systemInstruction = `Bạn là Gia sư AI Cá nhân (Student AI Tutor) đồng hành cùng học sinh lớp 12 ôn thi THPT Quốc gia môn Tiếng Anh (chương trình Global Success 12).
Nhiệm vụ của bạn:
1. Giải thích từ vựng (kèm IPA, từ loại, ví dụ), cấu trúc ngữ pháp và bài đọc hiểu dễ hiểu, súc tích.
2. Nếu học sinh nhờ chấm câu/đoạn văn tiếng Anh (mode = "writing_check"): Hãy chấm điểm trên thang 10, chỉ rõ từng lỗi ngữ pháp/từ vựng, giải thích vì sao sai và viết lại câu hoàn chỉnh.
3. Tư vấn lộ trình ôn tập cá nhân hóa.
RÀNG BUỘC SƯ PHẠM BẮT BUỘC (Guardrails):
- Áp dụng phương pháp Socratic: Hướng dẫn cách phân tích câu hỏi và loại trừ phương án nhiễu để học sinh hiểu bản chất, không làm bài hộ máy móc.
- Chỉ trả lời các nội dung liên quan đến môn Tiếng Anh và phương pháp học tập THPT.`;
    }

    if (aiConfig.apiKey) {
      const aiRes = await callGeminiWithFallback({
        apiKey: aiConfig.apiKey,
        preferredModel: aiConfig.model,
        systemInstruction,
        userPrompt: `[Vai trò: ${userRole.toUpperCase()} | Chế độ: ${mode || 'general'} | Unit: ${unitNumber || 'Chung'}]\nNgữ cảnh: ${contextText || 'Không có'}\n\nYêu cầu: ${message}`,
      });

      if (aiRes.ok) {
        return res.json({
          isAvailable: true,
          answer: aiRes.text,
          modelUsed: aiRes.modelUsed,
          role: userRole,
        });
      }
    }

    // Fallback thông minh theo vai trò khi chưa cấu hình API Key hoặc ngoại tuyến
    return res.json({
      isAvailable: false,
      isSmartFallback: true,
      role: userRole,
      answer: buildRoleSmartFallback(userRole, mode, message, unitNumber),
    });
  });

  // Endpoint AI Sinh Câu hỏi Trắc nghiệm Tự động cho Giáo viên & Admin (không cần nhập thủ công)
  app.post('/api/ai/generate-questions', requireRoles(['teacher', 'admin']), async (req, res) => {
    const { unitNumber = 1, skill = 'grammar', difficulty = 2, count = 3, topicPrompt = '' } = req.body;
    const safeCount = Math.min(Math.max(Number(count) || 3, 1), 10);
    const aiConfig = await getActiveAiConfig(pool);

    if (aiConfig.apiKey) {
      const prompt = `Hãy tạo ${safeCount} câu hỏi trắc nghiệm Tiếng Anh lớp 12 (Global Success) cho Unit ${unitNumber}, kỹ năng "${skill}", độ khó ${difficulty}/3.
Chủ đề/Yêu cầu thêm: ${topicPrompt || 'Bám sát trọng tâm thi tốt nghiệp THPT'}.
BẮT BUỘC trả về đúng định dạng JSON Array thuần túy (không bọc markdown), mỗi phần tử có cấu trúc:
[
  {
    "stem": "Nội dung câu hỏi tiếng Anh...",
    "options": ["A. ...", "B. ...", "C. ...", "D. ..."],
    "correctIndex": 0,
    "explanation": "Giải thích chi tiết bằng tiếng Việt vì sao đáp án đó đúng..."
  }
]`;

      const aiRes = await callGeminiWithFallback({
        apiKey: aiConfig.apiKey,
        preferredModel: aiConfig.model,
        systemInstruction: 'Bạn là chuyên gia ra đề thi THPT Quốc gia môn Tiếng Anh. Chỉ trả về JSON Array hợp lệ.',
        userPrompt: prompt,
      });

      if (aiRes.ok) {
        try {
          const cleaned = aiRes.text.replace(/```json/gi, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(cleaned);
          if (Array.isArray(parsed) && parsed.length > 0) {
            const normalized = parsed.map((q, idx) => ({
              id: `ai_q_${Date.now()}_${idx}`,
              unitNumber: Number(unitNumber) || 1,
              skill: String(skill || 'grammar'),
              difficulty: Number(difficulty) || 2,
              stem: String(q.stem || ''),
              options: Array.isArray(q.options) && q.options.length === 4
                ? q.options.map(String)
                : ['A. Option 1', 'B. Option 2', 'C. Option 3', 'D. Option 4'],
              correctIndex: Number(q.correctIndex ?? 0),
              explanation: String(q.explanation || ''),
            }));
            return res.json({
              source: 'gemini_ai',
              questions: normalized,
            });
          }
        } catch (_) {}
      }
    }

    // Khi Gemini API chưa sẵn sàng -> Truy vấn câu hỏi thật từ bảng teacher_questions trong Database
    if (process.env.DATABASE_URL) {
      try {
        const dbRes = await pool.query(
          `SELECT * FROM teacher_questions WHERE unit_number = $1 ORDER BY created_at DESC LIMIT $2`,
          [Number(unitNumber) || 1, safeCount]
        );
        if (dbRes.rows.length > 0) {
          return res.json({
            source: 'database_question_bank',
            questions: dbRes.rows.map((r) => ({
              id: r.id,
              unitNumber: r.unit_number,
              skill: r.skill,
              difficulty: r.difficulty,
              stem: r.stem,
              options: Array.isArray(r.options_json) ? r.options_json : [],
              correctIndex: r.correct_index,
              explanation: r.explanation,
            })),
          });
        }
      } catch (_) {}
    }

    res.json({
      source: 'unconfigured',
      questions: [],
    });
  });

  // Endpoint AI Số hóa Học liệu & Sách Giáo Khoa Mới cho Admin (không cần nhập thủ công)
  app.post('/api/ai/digitize-curriculum', requireRoles(['admin', 'teacher']), async (req, res) => {
    const { unitNumber = 1, rawText = '', title = '' } = req.body;
    if (!rawText || String(rawText).trim().length < 10) {
      return res.status(400).json({ error: 'Vui lòng dán nội dung văn bản hoặc mô tả bài học từ sách mới (tối thiểu 10 ký tự).' });
    }

    const aiConfig = await getActiveAiConfig(pool);
    if (aiConfig.apiKey) {
      const prompt = `Hãy số hóa đoạn văn bản sách giáo khoa Tiếng Anh 12 sau đây thành cấu trúc bài học chuẩn JSON cho Unit ${unitNumber} (${title || 'Bài học mới'}):
Nội dung gốc:
"""
${rawText}
"""
BẮT BUỘC trả về JSON Object thuần túy (không bọc markdown) theo cấu trúc:
{
  "unitNumber": ${Number(unitNumber) || 1},
  "title": "Tiêu đề Unit...",
  "readingPassage": "Đoạn văn bài đọc tiếng Anh...",
  "translationVi": "Bản dịch tiếng Việt sát nghĩa...",
  "grammarSummary": "Tóm tắt cấu trúc ngữ pháp trọng tâm...",
  "vocabulary": [
    {"english": "word", "ipa": "/.../", "meaningVi": "nghĩa tiếng Việt", "example": "Câu ví dụ"}
  ],
  "questions": [
    {"stem": "Câu hỏi đọc hiểu / ngữ pháp...", "options": ["A. ...", "B. ...", "C. ...", "D. ..."], "correctIndex": 0, "explanation": "Giải thích..."}
  ]
}`;

      const aiRes = await callGeminiWithFallback({
        apiKey: aiConfig.apiKey,
        preferredModel: aiConfig.model,
        systemInstruction: 'Bạn là chuyên gia số hóa sách giáo khoa Tiếng Anh THPT. Chỉ trả về JSON hợp lệ.',
        userPrompt: prompt,
      });

      if (aiRes.ok) {
        try {
          const cleaned = aiRes.text.replace(/```json/gi, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(cleaned);
          return res.json({
            source: 'gemini_ai',
            digitizedUnit: parsed,
          });
        } catch (_) {}
      }
    }

    // Built-in smart text parser fallback
    const digitized = buildSmartDigitizedCurriculum(Number(unitNumber) || 1, title, rawText);
    res.json({
      source: 'builtin_smart_digitizer',
      digitizedUnit: digitized,
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Trung tâm Dịch thuật Đa phương thức (Text Realtime • Voice • Ảnh chụp OCR)
  // ---------------------------------------------------------------------------
  app.post('/api/translate/text', authenticateToken, attachFreshUser, async (req, res) => {
    const { text, sourceLang = 'en', targetLang = 'vi' } = req.body;
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      return res.status(400).json({ error: 'Văn bản cần dịch không được để trống.' });
    }

    if (req.user.role === 'student') {
      const activeExam = await checkStudentExamLock(pool, req.user.id);
      if (activeExam) {
        return res.status(403).json({
          examLocked: true,
          error: `🔒 Công cụ Dịch thuật bị khóa khi đang trong Phòng thi có giám sát: "${activeExam.title}".`,
        });
      }
    }

    try {
      const gUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${encodeURIComponent(sourceLang)}&tl=${encodeURIComponent(targetLang)}&dt=t&q=${encodeURIComponent(text.trim())}`;
      const gRes = await fetch(gUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0' },
      });
      if (gRes.ok) {
        const data = await gRes.json();
        if (Array.isArray(data) && Array.isArray(data[0])) {
          const translated = data[0].map((seg) => (Array.isArray(seg) ? seg[0] : '')).join('').trim();
          return res.json({
            originalText: text.trim(),
            translatedText: translated,
            sourceLang,
            targetLang,
          });
        }
      }
    } catch (_) {}

    res.status(502).json({ error: 'Không thể kết nối dịch vụ dịch trực tuyến lúc này.' });
  });

  app.post('/api/translate/ocr', authenticateToken, attachFreshUser, async (req, res) => {
    const { imageBase64, mimeType = 'image/jpeg', extractedText = '', sourceLang = 'en', targetLang = 'vi' } = req.body;

    if (req.user.role === 'student') {
      const activeExam = await checkStudentExamLock(pool, req.user.id);
      if (activeExam) {
        return res.status(403).json({
          examLocked: true,
          error: `🔒 Dịch bằng hình ảnh (OCR) bị khóa khi đang trong Phòng thi có giám sát: "${activeExam.title}".`,
        });
      }
    }

    const aiConfig = await getActiveAiConfig(pool);

    // Nếu có ảnh chụp và đã cấu hình Gemini Vision API -> Quét OCR + Dịch song ngữ trực tiếp từ ảnh
    if (imageBase64 && aiConfig.apiKey) {
      const ocrPrompt = `Hãy đọc toàn bộ văn bản trong bức ảnh này (OCR) và dịch sang ${targetLang === 'vi' ? 'Tiếng Việt' : 'Tiếng Anh'}, đồng thời rút trích 3-5 từ vựng học thuật quan trọng.
Trả về JSON thuần túy theo cấu trúc:
{
  "recognizedText": "Văn bản gốc trích xuất từ ảnh...",
  "translatedText": "Bản dịch đầy đủ...",
  "keyVocabulary": [
    {"word": "...", "ipa": "/.../", "meaning": "..."}
  ]
}`;
      const visionRes = await callGeminiWithFallback({
        apiKey: aiConfig.apiKey,
        preferredModel: aiConfig.model,
        systemInstruction: 'Bạn là công cụ OCR và Dịch thuật học thuật chính xác. Chỉ trả về JSON.',
        userPrompt: ocrPrompt,
        imageBase64,
        mimeType,
      });

      if (visionRes.ok) {
        try {
          const cleaned = visionRes.text.replace(/```json/gi, '').replace(/```/g, '').trim();
          const parsed = JSON.parse(cleaned);
          return res.json({
            isSuccess: true,
            source: 'gemini_vision_ocr',
            recognizedText: parsed.recognizedText || '',
            translatedText: parsed.translatedText || '',
            keyVocabulary: Array.isArray(parsed.keyVocabulary) ? parsed.keyVocabulary : [],
          });
        } catch (_) {
          return res.json({
            isSuccess: true,
            source: 'gemini_vision_raw',
            recognizedText: 'Đã quét nội dung từ ảnh',
            translatedText: visionRes.text,
            keyVocabulary: [],
          });
        }
      }
    }

    // Nếu client gửi kèm văn bản trích xuất từ trang sách / OCR cục bộ -> Dịch trực tiếp
    if (extractedText && String(extractedText).trim().length > 0) {
      try {
        const gUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${encodeURIComponent(sourceLang)}&tl=${encodeURIComponent(targetLang)}&dt=t&q=${encodeURIComponent(extractedText.trim())}`;
        const gRes = await fetch(gUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } });
        if (gRes.ok) {
          const data = await gRes.json();
          const translated = Array.isArray(data?.[0])
            ? data[0].map((seg) => (Array.isArray(seg) ? seg[0] : '')).join('').trim()
            : '';
          return res.json({
            isSuccess: true,
            source: 'text_ocr_translation',
            recognizedText: extractedText.trim(),
            translatedText: translated,
            keyVocabulary: [],
          });
        }
      } catch (_) {}
    }

    res.status(400).json({
      isSuccess: false,
      error: 'Để quét chữ trực tiếp từ ảnh chụp Camera cần cấu hình GEMINI_API_KEY trong mục Cấu hình AI của Admin, hoặc chọn quét trang sách SGK có sẵn.',
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Cổng Giáo Viên (Teacher Portal) — FULL CRUD Câu hỏi, Tài liệu, Đề thi & Giám sát
  // ---------------------------------------------------------------------------

  // 4.1. CRUD Ngân hàng câu hỏi (Teacher & Admin)
  app.get('/api/teacher/questions', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ questions: [] });
    const { unitNumber, skill } = req.query;
    try {
      let query = 'SELECT * FROM teacher_questions WHERE 1=1';
      const params = [];
      if (unitNumber) {
        params.push(Number(unitNumber));
        query += ` AND unit_number = $${params.length}`;
      }
      if (skill && skill !== 'all') {
        params.push(String(skill));
        query += ` AND skill = $${params.length}`;
      }
      query += ' ORDER BY created_at DESC LIMIT 200';
      const result = await pool.query(query, params);
      res.json({ questions: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/teacher/questions', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    try {
      // Hỗ trợ cả thêm 1 câu hỏi hoặc thêm hàng loạt từ AI Generator
      const items = Array.isArray(req.body.questions) ? req.body.questions : [req.body];
      const inserted = [];
      for (const item of items) {
        const qId = item.id || `tq_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
        const options = Array.isArray(item.options) ? item.options : [];
        if (!item.stem || options.length < 2) continue;

        const rowRes = await pool.query(
          `INSERT INTO teacher_questions (id, grade, unit_number, skill, difficulty, stem, options_json, correct_index, explanation, created_by)
           VALUES ($1, 12, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (id) DO UPDATE SET
             unit_number = EXCLUDED.unit_number,
             skill = EXCLUDED.skill,
             difficulty = EXCLUDED.difficulty,
             stem = EXCLUDED.stem,
             options_json = EXCLUDED.options_json,
             correct_index = EXCLUDED.correct_index,
             explanation = EXCLUDED.explanation,
             updated_at = CURRENT_TIMESTAMP
           RETURNING *`,
          [
            qId,
            Number(item.unitNumber || item.unit_number || 1),
            String(item.skill || 'grammar'),
            Number(item.difficulty || 2),
            String(item.stem).trim(),
            JSON.stringify(options),
            Number(item.correctIndex ?? item.correct_index ?? 0),
            String(item.explanation || '').trim(),
            req.user.id,
          ]
        );
        inserted.push(rowRes.rows[0]);
      }

      await logAudit(pool, req.user, 'CREATE_QUESTIONS', 'teacher_questions', `${inserted.length}_items`, {
        count: inserted.length,
      });

      res.status(201).json({
        message: `Đã lưu ${inserted.length} câu hỏi vào Ngân hàng câu hỏi.`,
        questions: inserted,
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/teacher/questions/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { unitNumber, skill, difficulty, stem, options, correctIndex, explanation } = req.body;
    try {
      const result = await pool.query(
        `UPDATE teacher_questions
         SET unit_number = COALESCE($1, unit_number),
             skill = COALESCE($2, skill),
             difficulty = COALESCE($3, difficulty),
             stem = COALESCE($4, stem),
             options_json = COALESCE($5, options_json),
             correct_index = COALESCE($6, correct_index),
             explanation = COALESCE($7, explanation),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $8
         RETURNING *`,
        [
          unitNumber !== undefined ? Number(unitNumber) : null,
          skill || null,
          difficulty !== undefined ? Number(difficulty) : null,
          stem || null,
          Array.isArray(options) ? JSON.stringify(options) : null,
          correctIndex !== undefined ? Number(correctIndex) : null,
          explanation !== undefined ? String(explanation) : null,
          id,
        ]
      );
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Không tìm thấy câu hỏi cần sửa.' });
      }
      await logAudit(pool, req.user, 'UPDATE_QUESTION', 'teacher_questions', id, { stem });
      res.json({ message: 'Đã cập nhật câu hỏi thành công.', question: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/teacher/questions/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    try {
      await pool.query('DELETE FROM teacher_questions WHERE id = $1', [id]);
      await logAudit(pool, req.user, 'DELETE_QUESTION', 'teacher_questions', id, {});
      res.json({ message: 'Đã xóa câu hỏi khỏi ngân hàng đề.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 4.2. CRUD Bài học bổ trợ & Tài liệu lớp học (Materials CRUD)
  app.get('/api/teacher/materials', authenticateToken, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ materials: [] });
    try {
      const result = await pool.query('SELECT * FROM teacher_materials ORDER BY created_at DESC LIMIT 100');
      res.json({ materials: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/teacher/materials', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { unitNumber = 1, category = 'reading', title, content, vocabulary = [] } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: 'Tiêu đề và nội dung tài liệu không được để trống.' });
    }
    try {
      const id = `mat_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO teacher_materials (id, unit_number, category, title, content, vocabulary_json, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [id, Number(unitNumber), category, title.trim(), content.trim(), JSON.stringify(vocabulary), req.user.id]
      );
      await logAudit(pool, req.user, 'CREATE_MATERIAL', 'teacher_materials', id, { title });
      res.status(201).json({ message: 'Đã tạo tài liệu học tập mới.', material: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/teacher/materials/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { unitNumber, category, title, content, vocabulary } = req.body;
    try {
      const result = await pool.query(
        `UPDATE teacher_materials
         SET unit_number = COALESCE($1, unit_number),
             category = COALESCE($2, category),
             title = COALESCE($3, title),
             content = COALESCE($4, content),
             vocabulary_json = COALESCE($5, vocabulary_json),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $6
         RETURNING *`,
        [
          unitNumber !== undefined ? Number(unitNumber) : null,
          category || null,
          title || null,
          content || null,
          Array.isArray(vocabulary) ? JSON.stringify(vocabulary) : null,
          id,
        ]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy tài liệu.' });
      await logAudit(pool, req.user, 'UPDATE_MATERIAL', 'teacher_materials', id, { title });
      res.json({ message: 'Đã cập nhật tài liệu thành công.', material: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/teacher/materials/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    try {
      await pool.query('DELETE FROM teacher_materials WHERE id = $1', [id]);
      await logAudit(pool, req.user, 'DELETE_MATERIAL', 'teacher_materials', id, {});
      res.json({ message: 'Đã xóa tài liệu học tập.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 4.3. CRUD Kỳ thi có giám sát & Hạn nộp (Supervised Exams CRUD)
  app.get('/api/teacher/exams', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ exams: [] });
    try {
      const result = await pool.query(`
        SELECT e.*,
          (SELECT COUNT(*)::int FROM exam_live_sessions s WHERE s.exam_id = e.id) AS total_participants,
          (SELECT COUNT(*)::int FROM exam_live_sessions s WHERE s.exam_id = e.id AND s.status IN ('in_progress', 'warning_out_of_app')) AS active_count,
          (SELECT COUNT(*)::int FROM exam_live_sessions s WHERE s.exam_id = e.id AND s.violation_count > 0) AS violation_students
        FROM supervised_exams e
        ORDER BY e.created_at DESC
      `);
      res.json({ exams: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/teacher/exams', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const {
      title,
      description = '',
      durationMinutes = 45,
      deadlineAt,
      graceSeconds = 10,
      maxViolations = 2,
      violationAction = 'force_submit',
      questions = [],
    } = req.body;

    if (!title || String(title).trim().length === 0) {
      return res.status(400).json({ error: 'Vui lòng nhập tiêu đề kỳ thi có giám sát.' });
    }

    try {
      const examId = `sexam_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const finalQuestions = Array.isArray(questions) && questions.length > 0
        ? questions
        : buildGeneratedQuestionsFallback(1, 'grammar', 2, 10, title);

      const result = await pool.query(
        `INSERT INTO supervised_exams
          (id, title, description, duration_minutes, deadline_at, grace_seconds, max_violations, violation_action, questions_json, is_active, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, TRUE, $10)
         RETURNING *`,
        [
          examId,
          String(title).trim(),
          String(description || '').trim(),
          Number(durationMinutes) || 45,
          deadlineAt ? new Date(deadlineAt).toISOString() : new Date(Date.now() + 7 * 86400000).toISOString(),
          Number(graceSeconds) || 10,
          Number(maxViolations) || 2,
          violationAction === 'invalidate' ? 'invalidate' : 'force_submit',
          JSON.stringify(finalQuestions),
          req.user.id,
        ]
      );

      await logAudit(pool, req.user, 'CREATE_SUPERVISED_EXAM', 'supervised_exams', examId, {
        title,
        graceSeconds,
        maxViolations,
      });

      res.status(201).json({
        message: 'Đã tạo kỳ thi có giám sát thành công.',
        exam: result.rows[0],
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/teacher/exams/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { title, description, durationMinutes, deadlineAt, graceSeconds, maxViolations, violationAction, isActive, questions } = req.body;
    try {
      const result = await pool.query(
        `UPDATE supervised_exams
         SET title = COALESCE($1, title),
             description = COALESCE($2, description),
             duration_minutes = COALESCE($3, duration_minutes),
             deadline_at = COALESCE($4, deadline_at),
             grace_seconds = COALESCE($5, grace_seconds),
             max_violations = COALESCE($6, max_violations),
             violation_action = COALESCE($7, violation_action),
             is_active = COALESCE($8, is_active),
             questions_json = COALESCE($9, questions_json),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $10
         RETURNING *`,
        [
          title || null,
          description !== undefined ? description : null,
          durationMinutes !== undefined ? Number(durationMinutes) : null,
          deadlineAt ? new Date(deadlineAt).toISOString() : null,
          graceSeconds !== undefined ? Number(graceSeconds) : null,
          maxViolations !== undefined ? Number(maxViolations) : null,
          violationAction || null,
          isActive !== undefined ? Boolean(isActive) : null,
          Array.isArray(questions) ? JSON.stringify(questions) : null,
          id,
        ]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy kỳ thi.' });
      await logAudit(pool, req.user, 'UPDATE_SUPERVISED_EXAM', 'supervised_exams', id, { title, isActive });
      res.json({ message: 'Đã cập nhật cấu hình kỳ thi.', exam: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/teacher/exams/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    try {
      await pool.query('DELETE FROM supervised_exams WHERE id = $1', [id]);
      await logAudit(pool, req.user, 'DELETE_SUPERVISED_EXAM', 'supervised_exams', id, {});
      res.json({ message: 'Đã xóa kỳ thi có giám sát.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 4.4. Bảng Giám sát Phòng thi Trực tiếp (Live Proctoring Dashboard) & Can thiệp của Giáo viên
  app.get('/api/teacher/exams/:examId/live-sessions', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ sessions: [] });
    const { examId } = req.params;
    try {
      const examRes = await pool.query('SELECT * FROM supervised_exams WHERE id = $1', [examId]);
      const sessionsRes = await pool.query(
        'SELECT * FROM exam_live_sessions WHERE exam_id = $1 ORDER BY last_heartbeat_at DESC',
        [examId]
      );
      res.json({
        exam: examRes.rows[0] || null,
        sessions: sessionsRes.rows,
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/teacher/exams/:examId/sessions/:sessionId/action', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { examId, sessionId } = req.params;
    const { action, message, reason } = req.body;

    try {
      const sessionRes = await pool.query(
        'SELECT * FROM exam_live_sessions WHERE id = $1 AND exam_id = $2',
        [sessionId, examId]
      );
      if (sessionRes.rows.length === 0) {
        return res.status(404).json({ error: 'Không tìm thấy phiên thi của học sinh.' });
      }
      const session = sessionRes.rows[0];
      const examRes = await pool.query('SELECT * FROM supervised_exams WHERE id = $1', [examId]);
      const exam = examRes.rows[0];

      if (action === 'warn') {
        const warnMsg = message || 'Giáo viên nhắc nhở: Hệ thống phát hiện dấu hiệu mất tập trung. Vui lòng tập trung làm bài nghiêm túc!';
        const updated = await pool.query(
          `UPDATE exam_live_sessions
           SET teacher_warning_message = $1, last_heartbeat_at = CURRENT_TIMESTAMP
           WHERE id = $2 RETURNING *`,
          [warnMsg, sessionId]
        );
        await logAudit(pool, req.user, 'PROCTOR_WARN_STUDENT', 'exam_live_sessions', sessionId, { warnMsg });
        return res.json({ message: 'Đã gửi cảnh báo trực tiếp tới màn hình học sinh.', session: updated.rows[0] });
      }

      if (action === 'force_submit') {
        const { score } = calculateSupervisedExamScore(exam?.questions_json, session.current_answers);
        const updated = await pool.query(
          `UPDATE exam_live_sessions
           SET status = 'force_submitted_teacher',
               score = $1,
               teacher_warning_message = $2,
               submitted_at = CURRENT_TIMESTAMP,
               last_heartbeat_at = CURRENT_TIMESTAMP
           WHERE id = $3 RETURNING *`,
          [
            score,
            reason || 'Giáo viên đã chủ động thu bài thi của bạn do phát hiện hành vi khả nghi.',
            sessionId,
          ]
        );
        await logAudit(pool, req.user, 'PROCTOR_FORCE_SUBMIT', 'exam_live_sessions', sessionId, { score, reason });
        return res.json({ message: 'Đã thu bài của học sinh ngay lập tức.', session: updated.rows[0] });
      }

      if (action === 'invalidate') {
        const updated = await pool.query(
          `UPDATE exam_live_sessions
           SET status = 'invalidated',
               score = 0,
               teacher_warning_message = $1,
               submitted_at = CURRENT_TIMESTAMP,
               last_heartbeat_at = CURRENT_TIMESTAMP
           WHERE id = $2 RETURNING *`,
          [
            reason || 'Bài thi bị hủy kết quả do vi phạm quy chế phòng thi (thoát ứng dụng / sao chép tài liệu).',
            sessionId,
          ]
        );
        await logAudit(pool, req.user, 'PROCTOR_INVALIDATE_EXAM', 'exam_live_sessions', sessionId, { reason });
        return res.json({ message: 'Đã hủy kết quả bài thi của học sinh vi phạm.', session: updated.rows[0] });
      }

      if (action === 'reset_violation') {
        const updated = await pool.query(
          `UPDATE exam_live_sessions
           SET status = 'in_progress',
               violation_count = 0,
               teacher_warning_message = 'Giáo viên đã xác nhận sự cố kỹ thuật và cho phép bạn tiếp tục làm bài.',
               submitted_at = NULL,
               last_heartbeat_at = CURRENT_TIMESTAMP
           WHERE id = $1 RETURNING *`,
          [sessionId]
        );
        await logAudit(pool, req.user, 'PROCTOR_RESET_VIOLATION', 'exam_live_sessions', sessionId, {});
        return res.json({ message: 'Đã xóa cảnh báo và cho phép học sinh tiếp tục làm bài.', session: updated.rows[0] });
      }

      res.status(400).json({ error: 'Hành động giám sát không hợp lệ.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 4.5. Thống kê danh sách học viên cho Giáo viên
  app.get('/api/teacher/students', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ students: [] });
    try {
      const result = await pool.query(`
        SELECT u.id, u.email, u.display_name, u.role, u.is_locked, u.created_at,
               COALESCE(p.target_score, 7.0) AS target_score,
               COALESCE(p.current_streak, 0) AS streak,
               COALESCE((SELECT SUM(xp_earned) FROM daily_stats d WHERE d.user_id = u.id), p.total_xp, 0)::int AS total_xp,
               (SELECT COUNT(*)::int FROM exam_live_sessions s WHERE s.user_id = u.id) AS supervised_exams_taken
        FROM users u
        LEFT JOIN user_profiles p ON p.user_id = u.id
        WHERE u.role = 'student'
        ORDER BY total_xp DESC LIMIT 100
      `);
      res.json({ students: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // ---------------------------------------------------------------------------
  // 5. Luồng Học sinh làm bài thi có giám sát (Anti-Cheat 10s Countdown & Deadline)
  // ---------------------------------------------------------------------------
  app.get('/api/exams/supervised', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ exams: [] });
    try {
      const result = await pool.query(`
        SELECT e.id, e.title, e.description, e.duration_minutes, e.deadline_at,
               e.grace_seconds, e.max_violations, e.violation_action, e.is_active,
               jsonb_array_length(e.questions_json) AS question_count,
               (SELECT row_to_json(s) FROM (
                  SELECT id, status, score, violation_count, started_at, submitted_at
                  FROM exam_live_sessions
                  WHERE exam_id = e.id AND user_id = $1
                  ORDER BY started_at DESC LIMIT 1
               ) s) AS my_session
        FROM supervised_exams e
        WHERE e.is_active = TRUE
        ORDER BY e.created_at DESC
      `, [req.user.id]);
      res.json({ exams: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/exams/supervised/:examId/start', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { examId } = req.params;
    try {
      const examRes = await pool.query('SELECT * FROM supervised_exams WHERE id = $1 AND is_active = TRUE', [examId]);
      if (examRes.rows.length === 0) {
        return res.status(404).json({ error: 'Kỳ thi không tồn tại hoặc đã đóng.' });
      }
      const exam = examRes.rows[0];
      const questions = Array.isArray(exam.questions_json) ? exam.questions_json : [];

      // Kiểm tra xem học viên đã có phiên đang làm dở chưa
      const existingRes = await pool.query(
        `SELECT * FROM exam_live_sessions WHERE exam_id = $1 AND user_id = $2 ORDER BY started_at DESC LIMIT 1`,
        [examId, req.user.id]
      );

      if (existingRes.rows.length > 0) {
        const existing = existingRes.rows[0];
        if (['in_progress', 'warning_out_of_app'].includes(existing.status)) {
          return res.json({
            exam,
            session: existing,
            resumed: true,
          });
        }
      }

      const sessionId = `ses_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const newSessionRes = await pool.query(
        `INSERT INTO exam_live_sessions
          (id, exam_id, user_id, student_name, student_email, status, total_questions)
         VALUES ($1, $2, $3, $4, $5, 'in_progress', $6)
         RETURNING *`,
        [
          sessionId,
          examId,
          req.user.id,
          req.user.displayName || 'Học viên',
          req.user.email || '',
          questions.length,
        ]
      );

      res.status(201).json({
        exam,
        session: newSessionRes.rows[0],
        resumed: false,
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Heartbeat & Báo cáo sự kiện rời ứng dụng (Anti-cheat 10s enforcement)
  app.post('/api/exams/supervised/:examId/heartbeat', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { examId } = req.params;
    const {
      sessionId,
      currentAnswers = {},
      answeredCount = 0,
      eventType = 'heartbeat', // 'heartbeat' | 'app_backgrounded' | 'app_resumed' | 'timeout_10s_exceeded'
      outOfAppSeconds = 0,
      detail = '',
    } = req.body;

    try {
      const examRes = await pool.query('SELECT * FROM supervised_exams WHERE id = $1', [examId]);
      if (examRes.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy kỳ thi.' });
      const exam = examRes.rows[0];

      const sessionRes = await pool.query(
        'SELECT * FROM exam_live_sessions WHERE id = $1 AND exam_id = $2 AND user_id = $3',
        [sessionId, examId, req.user.id]
      );
      if (sessionRes.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy phiên làm bài.' });
      const session = sessionRes.rows[0];

      // Nếu Giáo viên đã thu bài hoặc hủy bài từ xa -> Báo ngay cho máy học sinh dừng làm bài
      if (!['in_progress', 'warning_out_of_app'].includes(session.status)) {
        return res.json({
          forceTerminated: true,
          status: session.status,
          score: Number(session.score || 0),
          message: session.teacher_warning_message || 'Phiên làm bài của bạn đã kết thúc theo lệnh của Giáo viên giám sát.',
          session,
        });
      }

      let newViolationCount = Number(session.violation_count || 0);
      const logs = Array.isArray(session.violation_logs) ? [...session.violation_logs] : [];
      let newStatus = 'in_progress';
      let autoTerminate = false;
      let terminateReason = '';

      const graceLimit = Number(exam.grace_seconds || 10);
      const maxViolations = Number(exam.max_violations || 2);

      if (eventType === 'app_backgrounded') {
        newViolationCount += 1;
        newStatus = 'warning_out_of_app';
        logs.push({
          type: 'OUT_OF_APP',
          timestamp: new Date().toISOString(),
          detail: detail || 'Học sinh thoát ứng dụng / chuyển cửa sổ hoặc mở màn hình đa nhiệm.',
          violationNumber: newViolationCount,
        });
        if (newViolationCount > maxViolations) {
          autoTerminate = true;
          terminateReason = `Hệ thống tự động xử lý: Bạn đã rời khỏi màn hình phòng thi ${newViolationCount} lần (vượt quá giới hạn cho phép ${maxViolations} lần).`;
        }
      } else if (eventType === 'timeout_10s_exceeded' || Number(outOfAppSeconds) >= graceLimit) {
        newViolationCount += 1;
        logs.push({
          type: 'EXCEEDED_GRACE_TIME',
          timestamp: new Date().toISOString(),
          outOfAppSeconds: Number(outOfAppSeconds) || graceLimit,
          detail: `Rời khỏi ứng dụng quá ${graceLimit} giây không quay lại.`,
        });
        autoTerminate = true;
        terminateReason = `Hệ thống tự động xử lý: Bạn đã rời khỏi ứng dụng quá ${graceLimit} giây quy định của phòng thi.`;
      } else if (eventType === 'app_resumed') {
        logs.push({
          type: 'RETURNED_TO_APP',
          timestamp: new Date().toISOString(),
          outOfAppSeconds: Number(outOfAppSeconds) || 0,
        });
      }

      const mergedAnswers = (currentAnswers && Object.keys(currentAnswers).length > 0)
        ? currentAnswers
        : session.current_answers;

      if (autoTerminate) {
        const finalAction = exam.violation_action === 'invalidate' ? 'invalidated' : 'force_submitted_auto';
        const { score } = finalAction === 'invalidated'
          ? { score: 0.0 }
          : calculateSupervisedExamScore(exam.questions_json, mergedAnswers);

        const updated = await pool.query(
          `UPDATE exam_live_sessions
           SET status = $1,
               violation_count = $2,
               violation_logs = $3,
               current_answers = $4,
               answered_count = $5,
               score = $6,
               teacher_warning_message = $7,
               submitted_at = CURRENT_TIMESTAMP,
               last_heartbeat_at = CURRENT_TIMESTAMP
           WHERE id = $8 RETURNING *`,
          [
            finalAction,
            newViolationCount,
            JSON.stringify(logs),
            JSON.stringify(mergedAnswers),
            Number(answeredCount) || 0,
            score,
            terminateReason,
            sessionId,
          ]
        );

        await logAudit(pool, req.user, 'AUTO_ANTI_CHEAT_TERMINATE', 'exam_live_sessions', sessionId, {
          finalAction,
          violationCount: newViolationCount,
          outOfAppSeconds,
          score,
        });

        return res.json({
          forceTerminated: true,
          status: finalAction,
          score,
          message: terminateReason,
          session: updated.rows[0],
        });
      }

      const updated = await pool.query(
        `UPDATE exam_live_sessions
         SET status = $1,
             violation_count = $2,
             violation_logs = $3,
             current_answers = $4,
             answered_count = $5,
             last_heartbeat_at = CURRENT_TIMESTAMP
         WHERE id = $6 RETURNING *`,
        [
          newStatus,
          newViolationCount,
          JSON.stringify(logs),
          JSON.stringify(mergedAnswers),
          Number(answeredCount) || 0,
          sessionId,
        ]
      );

      res.json({
        forceTerminated: false,
        status: newStatus,
        violationCount: newViolationCount,
        maxViolations,
        graceSeconds: graceLimit,
        teacherWarningMessage: updated.rows[0].teacher_warning_message || null,
        session: updated.rows[0],
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Nộp bài thi có giám sát (Kiểm tra đúng hạn vs trễ hạn)
  app.post('/api/exams/supervised/:examId/submit', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { examId } = req.params;
    const { sessionId, answers = {}, isAutoForceSubmit = false, autoReason = '' } = req.body;

    try {
      const examRes = await pool.query('SELECT * FROM supervised_exams WHERE id = $1', [examId]);
      if (examRes.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy kỳ thi.' });
      const exam = examRes.rows[0];

      const sessionRes = await pool.query(
        'SELECT * FROM exam_live_sessions WHERE id = $1 AND exam_id = $2 AND user_id = $3',
        [sessionId, examId, req.user.id]
      );
      if (sessionRes.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy phiên thi.' });
      const session = sessionRes.rows[0];

      // Nếu đã bị giáo viên thu bài / hủy trước đó thì trả về kết quả đó
      if (['force_submitted_teacher', 'invalidated'].includes(session.status)) {
        return res.json({
          message: session.teacher_warning_message || 'Bài thi đã được xử lý bởi Giáo viên.',
          session,
          score: Number(session.score || 0),
        });
      }

      const finalAnswers = Object.keys(answers).length > 0 ? answers : session.current_answers;
      const { correctCount, totalQuestions, score } = calculateSupervisedExamScore(exam.questions_json, finalAnswers);

      const now = new Date();
      const deadline = exam.deadline_at ? new Date(exam.deadline_at) : null;
      const isLate = deadline ? now > deadline : false;

      let finalStatus = isLate ? 'submitted_late' : 'submitted_on_time';
      if (isAutoForceSubmit) {
        finalStatus = exam.violation_action === 'invalidate' ? 'invalidated' : 'force_submitted_auto';
      }
      const finalScore = finalStatus === 'invalidated' ? 0.0 : score;

      const updated = await pool.query(
        `UPDATE exam_live_sessions
         SET status = $1,
             current_answers = $2,
             answered_count = $3,
             total_questions = $4,
             score = $5,
             teacher_warning_message = COALESCE(NULLIF($6, ''), teacher_warning_message),
             submitted_at = CURRENT_TIMESTAMP,
             last_heartbeat_at = CURRENT_TIMESTAMP
         WHERE id = $7 RETURNING *`,
        [
          finalStatus,
          JSON.stringify(finalAnswers),
          Object.keys(finalAnswers).length,
          totalQuestions,
          finalScore,
          autoReason,
          sessionId,
        ]
      );

      res.json({
        message: finalStatus === 'submitted_on_time'
          ? 'Nộp bài đúng hạn thành công!'
          : (finalStatus === 'submitted_late'
            ? 'Đã nộp bài (Ghi nhận nộp trễ hạn so với quy định).'
            : (autoReason || 'Bài thi đã được tự động thu hồi do vi phạm quy chế phòng thi.')),
        status: finalStatus,
        correctCount,
        totalQuestions,
        score: finalScore,
        isLate,
        session: updated.rows[0],
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // ---------------------------------------------------------------------------
  // 6. Trung Tâm Quản Trị Admin (Admin Portal) — Users CRUD, Lock/RBAC, Curriculum Replacement & Audit Logs
  // ---------------------------------------------------------------------------
  app.get('/api/admin/overview', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({});
    try {
      const usersCount = await pool.query(`
        SELECT
          COUNT(*)::int AS total_users,
          COUNT(*) FILTER (WHERE role = 'student')::int AS student_count,
          COUNT(*) FILTER (WHERE role = 'teacher')::int AS teacher_count,
          COUNT(*) FILTER (WHERE role = 'admin')::int AS admin_count,
          COUNT(*) FILTER (WHERE is_locked = TRUE)::int AS locked_count
        FROM users
      `);
      const examsCount = await pool.query(`
        SELECT
          COUNT(*)::int AS total_exams,
          (SELECT COUNT(*)::int FROM exam_live_sessions WHERE violation_count > 0) AS total_violations
        FROM supervised_exams
      `);
      const curriculumCount = await pool.query(`
        SELECT COUNT(*)::int AS total_versions,
               (SELECT title FROM curriculum_sets WHERE is_active = TRUE LIMIT 1) AS active_curriculum
        FROM curriculum_sets
      `);

      res.json({
        users: usersCount.rows[0],
        exams: examsCount.rows[0],
        curriculums: curriculumCount.rows[0],
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 6.1. CRUD Người dùng & Phân quyền + Khóa tài khoản
  app.get('/api/admin/users', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ users: [] });
    const { role, search } = req.query;
    try {
      let query = `
        SELECT id, email, display_name, role, auth_provider, email_verified, is_locked, locked_reason, created_at
        FROM users WHERE 1=1
      `;
      const params = [];
      if (role && role !== 'all') {
        params.push(String(role));
        query += ` AND role = $${params.length}`;
      }
      if (search && String(search).trim().length > 0) {
        params.push(`%${String(search).trim().toLowerCase()}%`);
        query += ` AND (LOWER(email) LIKE $${params.length} OR LOWER(display_name) LIKE $${params.length})`;
      }
      query += ' ORDER BY created_at DESC LIMIT 200';
      const result = await pool.query(query, params);
      const users = result.rows.map((u) => (u.email && u.email.toLowerCase().trim() === 'tongan542@gmail.com') ? { ...u, role: 'admin' } : u);
      res.json({ users });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/admin/users', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { email, password, displayName, role = 'student' } = req.body;
    if (!email || !password || String(password).length < 6) {
      return res.status(400).json({ error: 'Vui lòng nhập email hợp lệ và mật khẩu tối thiểu 6 ký tự.' });
    }
    const validRoles = ['student', 'teacher', 'admin'];
    const finalRole = validRoles.includes(role) ? role : 'student';
    const cleanEmail = String(email).trim().toLowerCase();

    try {
      const userId = `usr_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const { hash, salt } = hashPassword(password);
      const result = await pool.query(
        `INSERT INTO users (id, email, password_hash, password_salt, display_name, auth_provider, role, email_verified)
         VALUES ($1, $2, $3, $4, $5, 'email', $6, TRUE)
         RETURNING id, email, display_name, role, is_locked, created_at`,
        [userId, cleanEmail, hash, salt, (displayName || cleanEmail.split('@')[0]).trim(), finalRole]
      );
      await pool.query(
        `INSERT INTO user_profiles (user_id, daily_minutes, current_streak, total_xp)
         VALUES ($1, 20, 0, 0) ON CONFLICT (user_id) DO NOTHING`,
        [userId]
      );
      await logAudit(pool, req.user, 'ADMIN_CREATE_USER', 'users', userId, { email: cleanEmail, role: finalRole });
      res.status(201).json({
        message: `Đã tạo tài khoản ${finalRole.toUpperCase()} thành công.`,
        user: result.rows[0],
      });
    } catch (err) {
      if (err.code === '23505') {
        return res.status(409).json({ error: 'Email này đã tồn tại trong hệ thống.' });
      }
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/admin/users/:id', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { displayName, role, isLocked, lockedReason } = req.body;
    try {
      const result = await pool.query(
        `UPDATE users
         SET display_name = COALESCE($1, display_name),
             role = COALESCE($2, role),
             is_locked = COALESCE($3, is_locked),
             locked_reason = COALESCE($4, locked_reason),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $5
         RETURNING id, email, display_name, role, is_locked, locked_reason, created_at`,
        [
          displayName || null,
          role && ['student', 'teacher', 'admin'].includes(role) ? role : null,
          isLocked !== undefined ? Boolean(isLocked) : null,
          lockedReason !== undefined ? String(lockedReason) : null,
          id,
        ]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy người dùng.' });
      await logAudit(pool, req.user, 'ADMIN_UPDATE_USER', 'users', id, { role, isLocked, lockedReason });
      res.json({ message: 'Đã cập nhật thông tin & quyền người dùng.', user: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/admin/users/:id', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    if (id === req.user.id) {
      return res.status(400).json({ error: 'Không thể tự xóa tài khoản Admin đang đăng nhập.' });
    }
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [id]);
      await logAudit(pool, req.user, 'ADMIN_DELETE_USER', 'users', id, {});
      res.json({ message: 'Đã xóa tài khoản người dùng khỏi hệ thống.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 6.2. Quản lý Phiên bản Sách Giáo Khoa & Thay thế Bộ Sách Mới (Curriculum Versioning CRUD)
  app.get('/api/admin/curriculums', requireRoles(['admin', 'teacher']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ curriculums: [] });
    try {
      const result = await pool.query('SELECT * FROM curriculum_sets ORDER BY created_at DESC');
      res.json({ curriculums: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.get('/api/curriculums/active', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ activeCurriculum: null });
    try {
      const result = await pool.query('SELECT * FROM curriculum_sets WHERE is_active = TRUE ORDER BY updated_at DESC LIMIT 1');
      res.json({ activeCurriculum: result.rows[0] || null });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/admin/curriculums', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { versionCode, title, description = '', payload = {}, activateImmediately = false } = req.body;
    if (!title || !versionCode) {
      return res.status(400).json({ error: 'Vui lòng cung cấp mã phiên bản (versionCode) và tên bộ sách (title).' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const id = `cur_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      if (activateImmediately) {
        await client.query('UPDATE curriculum_sets SET is_active = FALSE');
      }
      const result = await client.query(
        `INSERT INTO curriculum_sets (id, version_code, title, description, is_active, payload_json, updated_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [
          id,
          String(versionCode).trim(),
          String(title).trim(),
          String(description).trim(),
          Boolean(activateImmediately),
          JSON.stringify(payload || {}),
          req.user.id,
        ]
      );
      await client.query('COMMIT');
      await logAudit(pool, req.user, 'ADMIN_CREATE_CURRICULUM', 'curriculum_sets', id, {
        versionCode,
        title,
        activateImmediately,
      });
      res.status(201).json({
        message: activateImmediately
          ? `Đã tạo và kích hoạt bộ sách "${title}" làm học liệu chính thức toàn hệ thống!`
          : `Đã lưu phiên bản bộ sách "${title}" thành công.`,
        curriculum: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      res.status(500).json({ error: err.message });
    } finally {
      client.release();
    }
  });

  app.put('/api/admin/curriculums/:id', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { versionCode, title, description, payload } = req.body;
    try {
      const result = await pool.query(
        `UPDATE curriculum_sets
         SET version_code = COALESCE($1, version_code),
             title = COALESCE($2, title),
             description = COALESCE($3, description),
             payload_json = COALESCE($4, payload_json),
             updated_by = $5,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $6 RETURNING *`,
        [
          versionCode || null,
          title || null,
          description !== undefined ? description : null,
          payload !== undefined ? JSON.stringify(payload) : null,
          req.user.id,
          id,
        ]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy bộ sách.' });
      await logAudit(pool, req.user, 'ADMIN_UPDATE_CURRICULUM', 'curriculum_sets', id, { title });
      res.json({ message: 'Đã cập nhật dữ liệu bộ sách giáo khoa.', curriculum: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/admin/curriculums/:id/activate', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('UPDATE curriculum_sets SET is_active = FALSE');
      const result = await client.query(
        `UPDATE curriculum_sets
         SET is_active = TRUE, updated_by = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2 RETURNING *`,
        [req.user.id, id]
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Không tìm thấy phiên bản bộ sách cần kích hoạt.' });
      }
      await client.query('COMMIT');
      await logAudit(pool, req.user, 'ADMIN_ACTIVATE_CURRICULUM', 'curriculum_sets', id, {
        title: result.rows[0].title,
        versionCode: result.rows[0].version_code,
      });
      res.json({
        message: `Đã thay thế và áp dụng bộ sách "${result.rows[0].title}" cho toàn hệ thống!`,
        curriculum: result.rows[0],
      });
    } catch (err) {
      await client.query('ROLLBACK');
      res.status(500).json({ error: err.message });
    } finally {
      client.release();
    }
  });

  app.delete('/api/admin/curriculums/:id', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    try {
      await pool.query('DELETE FROM curriculum_sets WHERE id = $1', [id]);
      await logAudit(pool, req.user, 'ADMIN_DELETE_CURRICULUM', 'curriculum_sets', id, {});
      res.json({ message: 'Đã xóa phiên bản bộ sách.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // 6.3. Nhật ký Giám sát Hệ thống (System Audit Logs)
  app.get('/api/admin/audit-logs', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ logs: [] });
    try {
      const result = await pool.query('SELECT * FROM system_audit_logs ORDER BY created_at DESC LIMIT 100');
      res.json({ logs: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/admin/audit-logs', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    try {
      await pool.query('DELETE FROM system_audit_logs WHERE created_at < NOW() - INTERVAL \'7 days\'');
      res.json({ message: 'Đã dọn dẹp các bản ghi nhật ký cũ.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // ---------------------------------------------------------------------------
  // 7. Quản lý Lớp học, Thành viên Lớp, Bài giao & Nộp bài (Giáo viên - Học sinh - Admin)
  // ---------------------------------------------------------------------------
  app.get('/api/classes', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ classes: [] });
    try {
      let query = '';
      let params = [];
      if (req.user.role === 'admin') {
        query = `
          SELECT c.*,
            (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = c.id AND m.status = 'active') AS student_count,
            (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = c.id AND m.status = 'pending') AS pending_count,
            (SELECT COUNT(*)::int FROM class_assignments a WHERE a.class_id = c.id AND a.status = 'open') AS open_assignment_count
          FROM classes c
          ORDER BY c.created_at DESC
        `;
      } else if (req.user.role === 'teacher') {
        query = `
          SELECT c.*,
            (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = c.id AND m.status = 'active') AS student_count,
            (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = c.id AND m.status = 'pending') AS pending_count,
            (SELECT COUNT(*)::int FROM class_assignments a WHERE a.class_id = c.id AND a.status = 'open') AS open_assignment_count
          FROM classes c
          WHERE c.teacher_id = $1 OR LOWER(c.teacher_email) = LOWER($2)
          ORDER BY c.created_at DESC
        `;
        params = [req.user.id, req.user.email || ''];
      } else {
        query = `
          SELECT c.*, m.status AS membership_status,
            (SELECT COUNT(*)::int FROM class_members cm WHERE cm.class_id = c.id AND cm.status = 'active') AS student_count,
            (SELECT COUNT(*)::int FROM class_assignments a WHERE a.class_id = c.id AND a.status = 'open') AS open_assignment_count
          FROM classes c
          JOIN class_members m ON m.class_id = c.id
          WHERE m.student_id = $1
          ORDER BY m.joined_at DESC
        `;
        params = [req.user.id];
      }
      const result = await pool.query(query, params);
      res.json({ classes: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Public endpoint: Tra cứu thông tin lớp học theo mã lớp (Không yêu cầu đăng nhập)
  app.get('/api/classes/lookup/:code', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ ok: false, error: 'Database chưa sẵn sàng.' });
    const { code } = req.params;
    if (!code || String(code).trim().length === 0) {
      return res.status(400).json({ ok: false, error: 'Vui lòng cung cấp mã lớp cần tìm.' });
    }
    try {
      const clsRes = await pool.query(
        `SELECT c.*,
           (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = c.id AND m.status = 'active') AS student_count
         FROM classes c
         WHERE UPPER(TRIM(c.join_code)) = UPPER(TRIM($1)) AND c.is_archived = FALSE
         LIMIT 1`,
        [String(code)]
      );
      if (clsRes.rows.length === 0) {
        return res.status(404).json({ ok: false, error: `Không tìm thấy lớp học với mã "${code}" trên máy chủ Cloud.` });
      }
      return res.json({ ok: true, classItem: clsRes.rows[0] });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  // Đồng bộ hàng loạt lớp học từ Giáo viên / Admin lên Cloud PostgreSQL
  app.post('/api/classes/batch-sync', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ ok: false, error: 'Database chưa sẵn sàng.' });
    const { classes } = req.body;
    if (!Array.isArray(classes) || classes.length === 0) {
      return res.status(400).json({ ok: false, error: 'Danh sách lớp đồng bộ rỗng.' });
    }
    const synced = [];
    try {
      for (const item of classes) {
        const id = item.id || `cls_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
        const name = (item.name || 'Lớp học').toString().trim();
        const code = (item.code || item.joinCode || item.join_code || `ENG-${crypto.randomBytes(2).toString('hex')}`).toString().trim().toUpperCase();
        const schoolName = (item.schoolName || item.school_name || '').toString().trim();
        const academicYear = (item.schoolYear || item.academicYear || item.academic_year || '2025-2026').toString().trim();
        const teacherId = item.teacherId || item.teacher_id || null;
        const teacherName = (item.teacherName || item.teacher_name || 'Giáo viên').toString().trim();
        const teacherEmail = (item.teacherEmail || item.teacher_email || '').toString().trim();
        const requireApproval = Boolean(item.requireApproval ?? item.require_approval ?? false);
        const showLeaderboard = Boolean(item.showLeaderboard ?? item.show_leaderboard ?? true);
        const allowJoin = Boolean(item.allowJoin ?? item.allow_join ?? true);
        const isArchived = Boolean(item.isArchived ?? item.is_archived ?? item.status === 'archived');

        const upsertRes = await pool.query(
          `INSERT INTO classes (id, name, school_name, academic_year, join_code, teacher_id, teacher_name, teacher_email, require_approval, show_leaderboard, allow_join, is_archived)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
           ON CONFLICT (id) DO UPDATE SET
             name = EXCLUDED.name,
             school_name = EXCLUDED.school_name,
             academic_year = EXCLUDED.academic_year,
             join_code = EXCLUDED.join_code,
             teacher_id = COALESCE(EXCLUDED.teacher_id, classes.teacher_id),
             teacher_name = COALESCE(EXCLUDED.teacher_name, classes.teacher_name),
             teacher_email = COALESCE(EXCLUDED.teacher_email, classes.teacher_email),
             require_approval = EXCLUDED.require_approval,
             show_leaderboard = EXCLUDED.show_leaderboard,
             allow_join = EXCLUDED.allow_join,
             is_archived = EXCLUDED.is_archived,
             updated_at = CURRENT_TIMESTAMP
           RETURNING *`,
          [id, name, schoolName, academicYear, code, teacherId, teacherName, teacherEmail, requireApproval, showLeaderboard, allowJoin, isArchived]
        );
        synced.push(upsertRes.rows[0]);
      }
      return res.json({ ok: true, message: `Đã đồng bộ thành công ${synced.length} lớp học lên máy chủ Cloud.`, syncedCount: synced.length, classes: synced });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.post('/api/classes', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const {
      id: customId,
      name,
      schoolName = '',
      academicYear = '2025-2026',
      joinCode,
      teacherId,
      teacherName,
      teacherEmail,
      requireApproval = false,
      showLeaderboard = true,
      allowJoin = true,
    } = req.body;
    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ error: 'Vui lòng nhập tên lớp học.' });
    }
    try {
      // Nhận diện user nếu có token (không ép buộc gây chặn lưu trên Cloud)
      let authUser = null;
      try {
        const authHeader = req.headers['authorization'];
        const token = authHeader && authHeader.split(' ')[1];
        if (token) authUser = verifyToken(token);
      } catch (_) {}

      const id = customId || `cls_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const code = (joinCode && String(joinCode).trim().length >= 4)
        ? String(joinCode).trim().toUpperCase()
        : `ENG-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
      const finalTeacherId = teacherId || (authUser?.role === 'teacher' ? authUser.id : null);
      const finalTeacherName = teacherName || (authUser ? (authUser.displayName || authUser.email) : 'Giáo viên');
      const finalTeacherEmail = teacherEmail || (authUser ? authUser.email : '');

      const result = await pool.query(
        `INSERT INTO classes (id, name, school_name, academic_year, join_code, teacher_id, teacher_name, teacher_email, require_approval, show_leaderboard, allow_join)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO UPDATE SET
           name = EXCLUDED.name,
           school_name = EXCLUDED.school_name,
           academic_year = EXCLUDED.academic_year,
           join_code = EXCLUDED.join_code,
           teacher_id = COALESCE(EXCLUDED.teacher_id, classes.teacher_id),
           teacher_name = COALESCE(EXCLUDED.teacher_name, classes.teacher_name),
           teacher_email = COALESCE(EXCLUDED.teacher_email, classes.teacher_email),
           require_approval = EXCLUDED.require_approval,
           show_leaderboard = EXCLUDED.show_leaderboard,
           allow_join = EXCLUDED.allow_join,
           updated_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [
          id,
          String(name).trim(),
          String(schoolName).trim(),
          String(academicYear).trim(),
          code,
          finalTeacherId,
          finalTeacherName,
          finalTeacherEmail,
          Boolean(requireApproval),
          Boolean(showLeaderboard),
          Boolean(allowJoin),
        ]
      );
      if (authUser) {
        await logAudit(pool, authUser, 'CREATE_CLASS', 'classes', id, { name, joinCode: code });
      }
      res.status(201).json({ message: 'Đã tạo lớp học thành công.', classItem: result.rows[0], class: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/classes/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { name, schoolName, academicYear, joinCode, teacherId, teacherName, teacherEmail, requireApproval, showLeaderboard, allowJoin, isArchived } = req.body;
    try {
      const result = await pool.query(
        `UPDATE classes
         SET name = COALESCE($1, name),
             school_name = COALESCE($2, school_name),
             academic_year = COALESCE($3, academic_year),
             join_code = COALESCE($4, join_code),
             teacher_id = COALESCE($5, teacher_id),
             teacher_name = COALESCE($6, teacher_name),
             teacher_email = COALESCE($7, teacher_email),
             require_approval = COALESCE($8, require_approval),
             show_leaderboard = COALESCE($9, show_leaderboard),
             allow_join = COALESCE($10, allow_join),
             is_archived = COALESCE($11, is_archived),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $12 RETURNING *`,
        [
          name || null,
          schoolName !== undefined ? schoolName : null,
          academicYear || null,
          joinCode ? String(joinCode).trim().toUpperCase() : null,
          teacherId !== undefined ? teacherId : null,
          teacherName !== undefined ? teacherName : null,
          teacherEmail !== undefined ? teacherEmail : null,
          requireApproval !== undefined ? Boolean(requireApproval) : null,
          showLeaderboard !== undefined ? Boolean(showLeaderboard) : null,
          allowJoin !== undefined ? Boolean(allowJoin) : null,
          isArchived !== undefined ? Boolean(isArchived) : null,
          id,
        ]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy lớp học.' });
      await logAudit(pool, req.user, 'UPDATE_CLASS', 'classes', id, { joinCode, teacherName, isArchived });
      res.json({ message: 'Đã cập nhật lớp học.', classItem: result.rows[0], class: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Xóa / Giải tán vĩnh viễn một lớp học
  app.delete('/api/classes/:id', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    try {
      let authUser = null;
      try {
        const authHeader = req.headers['authorization'];
        const token = authHeader && authHeader.split(' ')[1];
        if (token) authUser = verifyToken(token);
      } catch (_) {}

      // Xóa điểm nộp bài gắn với lớp nếu có
      await pool.query('DELETE FROM assignment_submissions WHERE class_id = $1', [id]).catch(() => {});
      // Xóa thành viên lớp
      await pool.query('DELETE FROM class_members WHERE class_id = $1', [id]).catch(() => {});
      // Xóa bài tập lớp
      await pool.query('DELETE FROM class_assignments WHERE class_id = $1', [id]).catch(() => {});

      // Xóa chính thức lớp học khỏi bảng classes
      const result = await pool.query('DELETE FROM classes WHERE id = $1 RETURNING *', [id]);
      if (result.rows.length === 0) {
        // Nếu không tìm thấy theo id, thử tìm theo join_code
        await pool.query('DELETE FROM classes WHERE UPPER(TRIM(join_code)) = UPPER(TRIM($1))', [id]).catch(() => {});
      }

      if (authUser) {
        await logAudit(pool, authUser, 'DELETE_CLASS', 'classes', id, { deletedClass: result.rows[0] || id });
      }
      res.json({ ok: true, message: 'Đã giải tán và xóa vĩnh viễn lớp học thành công.', deletedId: id });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    }
  });

  app.post('/api/classes/join', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { joinCode, studentId, studentName, studentEmail } = req.body;
    if (!joinCode || String(joinCode).trim().length === 0) {
      return res.status(400).json({ error: 'Vui lòng nhập mã lớp.' });
    }

    // Nhận diện người dùng: ưu tiên Bearer token nếu có, fallback sang thông tin body từ app mobile
    let authUser = null;
    try {
      const authHeader = req.headers['authorization'];
      const token = authHeader && authHeader.split(' ')[1];
      if (token) authUser = verifyToken(token);
    } catch (_) {}

    const targetStudentId = (authUser && authUser.id) || studentId || `stu_${Date.now()}`;
    const targetStudentName = (authUser && (authUser.displayName || authUser.email)) || studentName || 'Học sinh';
    const targetStudentEmail = (authUser && authUser.email) || studentEmail || '';

    try {
      const clsRes = await pool.query(
        'SELECT * FROM classes WHERE UPPER(TRIM(join_code)) = UPPER(TRIM($1)) AND is_archived = FALSE',
        [String(joinCode)]
      );
      if (clsRes.rows.length === 0) {
        return res.status(404).json({ error: `Không tìm thấy lớp học với mã "${joinCode}".` });
      }
      const cls = clsRes.rows[0];
      if (!cls.allow_join) {
        return res.status(403).json({ error: 'Lớp học này hiện đang khóa tiếp nhận thành viên mới.' });
      }
      const status = cls.require_approval ? 'pending' : 'active';
      const memId = `cm_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const memRes = await pool.query(
        `INSERT INTO class_members (id, class_id, student_id, student_name, student_email, status)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (class_id, student_id) DO UPDATE SET status = EXCLUDED.status, student_name = EXCLUDED.student_name, student_email = EXCLUDED.student_email
         RETURNING *`,
        [memId, cls.id, targetStudentId, targetStudentName, targetStudentEmail, status]
      );
      res.status(201).json({
        ok: true,
        message: status === 'pending'
          ? `Đã gửi yêu cầu tham gia lớp ${cls.name}. Chờ giáo viên phê duyệt.`
          : `Đã tham gia lớp ${cls.name} thành công!`,
        classItem: cls,
        class: cls,
        membership: memRes.rows[0],
      });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.get('/api/classes/:classId/members', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ members: [] });
    const { classId } = req.params;
    try {
      const result = await pool.query(
        `SELECT m.*,
           COALESCE(p.current_streak, 0) AS streak,
           COALESCE(p.target_score, 7.0) AS target_score,
           COALESCE((SELECT AVG(s.score)::numeric(5,2) FROM assignment_submissions s WHERE s.student_id = m.student_id AND s.class_id = m.class_id), 0.0) AS avg_score,
           (SELECT COUNT(*)::int FROM assignment_submissions s WHERE s.student_id = m.student_id AND s.class_id = m.class_id) AS submitted_count
         FROM class_members m
         LEFT JOIN user_profiles p ON p.user_id = m.student_id
         WHERE m.class_id = $1
         ORDER BY m.status DESC, m.joined_at DESC`,
        [classId]
      );
      res.json({ members: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/classes/:classId/members/:memberId/decision', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { classId, memberId } = req.params;
    const { status } = req.body; // 'active' | 'rejected'
    try {
      if (status === 'rejected') {
        await pool.query('DELETE FROM class_members WHERE id = $1 AND class_id = $2', [memberId, classId]);
        return res.json({ message: 'Đã từ chối yêu cầu vào lớp.' });
      }
      const result = await pool.query(
        `UPDATE class_members SET status = 'active' WHERE id = $1 AND class_id = $2 RETURNING *`,
        [memberId, classId]
      );
      res.json({ message: 'Đã duyệt học sinh vào lớp.', member: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Bài giao cho lớp & Kết quả nộp bài
  app.get('/api/assignments', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ assignments: [] });
    const { classId } = req.query;
    try {
      let query = `
        SELECT a.*,
          (SELECT COUNT(*)::int FROM assignment_submissions s WHERE s.assignment_id = a.id) AS submitted_count,
          (SELECT COUNT(*)::int FROM class_members m WHERE m.class_id = a.class_id AND m.status = 'active') AS total_students
        FROM class_assignments a
        WHERE 1=1
      `;
      const params = [];
      if (classId) {
        params.push(String(classId));
        query += ` AND a.class_id = $${params.length}`;
      }
      query += ' ORDER BY a.created_at DESC';
      const result = await pool.query(query, params);
      res.json({ assignments: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/assignments', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const {
      classId,
      className = '',
      title,
      assignmentType = 'unit_practice',
      unitNumber = 1,
      skills = ['reading'],
      examId = null,
      deadlineAt,
      maxAttempts = 2,
      showAnswersMode = 'after_submit',
      status = 'open',
    } = req.body;
    if (!title) return res.status(400).json({ error: 'Vui lòng nhập tiêu đề bài giao.' });
    try {
      const id = `asg_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO class_assignments
          (id, class_id, class_name, title, assignment_type, unit_number, skills_json, exam_id, deadline_at, max_attempts, show_answers_mode, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
         RETURNING *`,
        [
          id,
          classId || null,
          className,
          String(title).trim(),
          assignmentType,
          Number(unitNumber) || 1,
          JSON.stringify(Array.isArray(skills) ? skills : ['reading']),
          examId,
          deadlineAt ? new Date(deadlineAt).toISOString() : new Date(Date.now() + 3 * 86400000).toISOString(),
          Number(maxAttempts) || 2,
          showAnswersMode,
          status,
          req.user.id,
        ]
      );
      await logAudit(pool, req.user, 'CREATE_ASSIGNMENT', 'class_assignments', id, { title, className });
      res.status(201).json({ message: 'Đã giao bài cho lớp thành công.', assignment: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.delete('/api/assignments/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    try {
      await pool.query('DELETE FROM class_assignments WHERE id = $1', [req.params.id]);
      res.json({ message: 'Đã xóa bài giao.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/assignments/:id/submit', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { classId, score = 0, correctCount = 0, totalQuestions = 0, skillBreakdown = {} } = req.body;
    try {
      const asgRes = await pool.query('SELECT * FROM class_assignments WHERE id = $1', [id]);
      const asg = asgRes.rows[0];
      const isLate = asg?.deadline_at ? new Date() > new Date(asg.deadline_at) : false;
      const subId = `sub_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO assignment_submissions
          (id, assignment_id, class_id, student_id, student_name, student_email, score, correct_count, total_questions, skill_breakdown_json, is_late)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         RETURNING *`,
        [
          subId,
          id,
          classId || asg?.class_id || null,
          req.user.id,
          req.user.displayName || 'Học sinh',
          req.user.email || '',
          Number(score) || 0,
          Number(correctCount) || 0,
          Number(totalQuestions) || 0,
          JSON.stringify(skillBreakdown || {}),
          isLate,
        ]
      );
      res.status(201).json({ message: 'Đã nộp bài thành công.', submission: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Học sinh gửi giải trình khi bị tự động nộp bài sau 10 giây rời ứng dụng
  app.post('/api/exams/supervised/:examId/explain', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { examId } = req.params;
    const { sessionId, explanation } = req.body;
    if (!explanation || String(explanation).trim().length === 0) {
      return res.status(400).json({ error: 'Vui lòng nhập lý do giải trình.' });
    }
    try {
      const result = await pool.query(
        `UPDATE exam_live_sessions
         SET student_explanation = $1, explanation_submitted_at = CURRENT_TIMESTAMP
         WHERE id = $2 AND exam_id = $3
         RETURNING *`,
        [String(explanation).trim(), sessionId, examId]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy phiên thi.' });
      res.json({ message: 'Đã gửi giải trình tới Giáo viên giám sát.', session: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Báo lỗi câu hỏi thật từ Học sinh -> Giáo viên / Admin
  app.get('/api/bug-reports', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ reports: [] });
    try {
      const result = await pool.query('SELECT * FROM question_bug_reports ORDER BY created_at DESC LIMIT 200');
      res.json({ reports: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/bug-reports', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { questionId = '', unitNumber = 1, skill = 'reading', title, details = '', category = 'wrong_answer' } = req.body;
    if (!title) return res.status(400).json({ error: 'Vui lòng nhập tiêu đề lỗi.' });
    try {
      const id = `rpt_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO question_bug_reports (id, question_id, unit_number, skill, title, details, category, status, reporter_id, reported_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'new', $8, $9)
         RETURNING *`,
        [
          id,
          questionId,
          Number(unitNumber) || 1,
          skill,
          String(title).trim(),
          String(details).trim(),
          category,
          req.user.id,
          req.user.displayName || req.user.email || 'Học sinh',
        ]
      );
      res.status(201).json({ message: 'Cảm ơn bạn! Báo lỗi đã được gửi tới Giáo viên & Admin.', report: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.put('/api/bug-reports/:id', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { status } = req.body;
    try {
      const result = await pool.query(
        `UPDATE question_bug_reports SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *`,
        [status || 'resolved', req.params.id]
      );
      res.json({ message: 'Đã cập nhật trạng thái báo lỗi.', report: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Thông báo hệ thống & lớp học thật
  app.get('/api/announcements', authenticateToken, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ announcements: [] });
    try {
      const result = await pool.query('SELECT * FROM system_announcements ORDER BY sent_at DESC LIMIT 100');
      res.json({ announcements: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/announcements', requireRoles(['teacher', 'admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { title, content, target = 'all', type = 'general', classId = null } = req.body;
    if (!title) return res.status(400).json({ error: 'Vui lòng nhập tiêu đề thông báo.' });
    try {
      const id = `ann_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO system_announcements (id, title, content, target, type, class_id, sent_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [id, String(title).trim(), String(content || '').trim(), target, type, classId, req.user.id]
      );
      await logAudit(pool, req.user, 'SEND_ANNOUNCEMENT', 'system_announcements', id, { title, target });
      res.status(201).json({ message: 'Đã phát thông báo thành công.', announcement: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Yêu cầu duyệt Giáo viên thật
  app.get('/api/admin/teacher-requests', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.json({ requests: [] });
    try {
      const result = await pool.query(`SELECT * FROM teacher_requests WHERE status = 'pending' ORDER BY created_at DESC`);
      res.json({ requests: result.rows });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/teacher-requests', authenticateToken, attachFreshUser, async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { name, school = '', subject = 'Tiếng Anh 12' } = req.body;
    const email = req.user.email || '';
    const isVerifiedDomain = email.endsWith('.edu.vn') || email.endsWith('.edu');
    try {
      const id = `treq_${Date.now()}_${crypto.randomBytes(2).toString('hex')}`;
      const result = await pool.query(
        `INSERT INTO teacher_requests (id, user_id, name, email, school, subject, is_verified_domain, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
         RETURNING *`,
        [id, req.user.id, name || req.user.displayName || email, email, school, subject, isVerifiedDomain]
      );
      res.status(201).json({ message: 'Đã gửi hồ sơ đăng ký Giáo viên tới Quản trị viên.', request: result.rows[0] });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  app.post('/api/admin/teacher-requests/:id/decision', requireRoles(['admin']), async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ error: 'Database chưa sẵn sàng.' });
    const { id } = req.params;
    const { approve } = req.body;
    try {
      const reqRes = await pool.query('SELECT * FROM teacher_requests WHERE id = $1', [id]);
      if (reqRes.rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy yêu cầu.' });
      const treq = reqRes.rows[0];
      const newStatus = approve ? 'approved' : 'rejected';
      await pool.query('UPDATE teacher_requests SET status = $1 WHERE id = $2', [newStatus, id]);
      if (approve && treq.email) {
        await pool.query(`UPDATE users SET role = 'teacher', updated_at = CURRENT_TIMESTAMP WHERE LOWER(email) = LOWER($1)`, [treq.email]);
      }
      await logAudit(pool, req.user, approve ? 'APPROVE_TEACHER' : 'REJECT_TEACHER', 'teacher_requests', id, { email: treq.email });
      res.json({ message: approve ? 'Đã duyệt quyền Giáo viên.' : 'Đã từ chối yêu cầu.' });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });

  // Đồng bộ tiến độ học tập SGK của học sinh lên Cloud PostgreSQL
  app.post('/api/students/progress/sync', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ ok: false, error: 'Database chưa sẵn sàng.' });
    const { userId, userEmail, unitNumber, sectionName, status = 'completed', score = 100 } = req.body;
    if (!userId && !userEmail) {
      return res.status(400).json({ ok: false, error: 'Thiếu định danh học sinh (userId hoặc userEmail).' });
    }
    const finalUserId = userId || userEmail;
    const finalEmail = userEmail || '';
    const unit = parseInt(unitNumber, 10) || 1;
    const section = String(sectionName || 'general').trim();

    try {
      await pool.query(
        `INSERT INTO textbook_progress (user_id, user_email, unit_number, section_name, status, score, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
         ON CONFLICT (user_id, unit_number, section_name) DO UPDATE SET
           status = EXCLUDED.status,
           score = EXCLUDED.score,
           user_email = COALESCE(NULLIF(EXCLUDED.user_email, ''), textbook_progress.user_email),
           updated_at = CURRENT_TIMESTAMP`,
        [finalUserId, finalEmail, unit, section, status, score]
      );
      res.json({ ok: true, message: 'Đã lưu tiến độ học tập lên Cloud thành công.' });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    }
  });

  // Giáo viên/Admin tra cứu tiến độ học tập chi tiết của học sinh từ Cloud Render
  app.get('/api/students/:identifier/progress', async (req, res) => {
    if (!process.env.DATABASE_URL) return res.status(503).json({ ok: false, error: 'Database chưa sẵn sàng.' });
    const { identifier } = req.params;
    if (!identifier) {
      return res.status(400).json({ ok: false, error: 'Thiếu định danh học sinh.' });
    }

    try {
      // 1. Lấy tất cả các section SGK đã học
      const progressRes = await pool.query(
        `SELECT unit_number, section_name, status, score, updated_at
         FROM textbook_progress
         WHERE user_id = $1 OR LOWER(user_email) = LOWER($1)
         ORDER BY unit_number ASC, updated_at ASC`,
        [identifier]
      );

      // 2. Lấy thông tin tổng quan từ user_profiles (streak, target_score, ...)
      const profileRes = await pool.query(
        `SELECT p.*, u.display_name, u.email
         FROM users u
         LEFT JOIN user_profiles p ON p.user_id = u.id
         WHERE u.id = $1 OR LOWER(u.email) = LOWER($1)
         LIMIT 1`,
        [identifier]
      );

      // 3. Lấy điểm thi trung bình từ các bài tập đã nộp
      const subRes = await pool.query(
        `SELECT AVG(score)::numeric(5,2) as avg_score, COUNT(*)::int as submitted_count
         FROM assignment_submissions
         WHERE student_id = $1 OR LOWER(student_email) = LOWER($1)`,
        [identifier]
      );

      const profile = profileRes.rows[0] || {};
      const sub = subRes.rows[0] || {};

      res.json({
        ok: true,
        identifier,
        streakDays: profile.current_streak || 0,
        avgScore: parseFloat(sub.avg_score) || 0.0,
        submittedCount: sub.submitted_count || 0,
        completedSections: progressRes.rows,
        totalSectionsCompleted: progressRes.rows.filter(r => r.status === 'completed').length,
      });
    } catch (err) {
      res.status(500).json({ ok: false, error: err.message });
    }
  });
}

// ---------------------------------------------------------------------------
// Thông báo minh bạch khi chưa kết nối khóa Gemini API trực tuyến (Không tạo điểm/dữ liệu giả)
// ---------------------------------------------------------------------------
function buildRoleSmartFallback(role, mode, message, unitNumber) {
  const q = String(message || '').trim();
  return `⚠️ **[Thông báo Kết nối Dịch vụ AI]**\n` +
    `• Yêu cầu của bạn: *"${q}"*\n` +
    `• Hiện tại máy chủ chưa nhận được phản hồi từ Google Gemini API (hoặc đang ngoại tuyến).\n` +
    `• Hệ thống cam kết **không sinh câu trả lời mẫu hay chấm điểm giả lập**. Vui lòng kiểm tra biến môi trường \`GEMINI_API_KEY\` trên Render hoặc thử lại sau ít giây.`;
}

function buildGeneratedQuestionsFallback() {
  return [];
}

function buildSmartDigitizedCurriculum(unitNumber, title, rawText) {
  return {
    unitNumber,
    title: title || `Unit ${unitNumber}`,
    readingPassage: String(rawText || '').trim(),
    translationVi: '',
    grammarSummary: '',
    vocabulary: [],
    questions: [],
  };
}

module.exports = {
  initRbacAndProctoringTables,
  registerRbacProctorAiRoutes,
};

