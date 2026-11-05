import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'app_repository.dart';
import 'models/question.dart';
import 'models/topic.dart';
import 'models/user_profile.dart';
import 'models/word.dart';
import 'remote/api_client.dart';
import 'trial_lesson_repository.dart';
import '../ui/settings/notification_service.dart';

/// Khóa bảo vệ chống gian lận toàn cục khi Học viên đang ở trong Phòng thi có giám sát.
/// Tự động khóa toàn bộ tính năng Dịch thuật và Gia sư AI Chatbot.
class ExamLockGuard extends ChangeNotifier {
  ExamLockGuard._();
  static final ExamLockGuard instance = ExamLockGuard._();

  bool _isLocked = false;
  String? _activeExamId;
  String? _activeExamTitle;

  bool get isLocked => _isLocked;
  String? get activeExamId => _activeExamId;
  String? get activeExamTitle => _activeExamTitle;

  void enterSupervisedExam({
    required String examId,
    required String examTitle,
  }) {
    _isLocked = true;
    _activeExamId = examId;
    _activeExamTitle = examTitle;
    notifyListeners();
  }

  void exitSupervisedExam() {
    _isLocked = false;
    _activeExamId = null;
    _activeExamTitle = null;
    notifyListeners();
  }
}

/// Cầu nối gọi Nhận diện Giọng nói (Speech-to-Text) và Chụp ảnh/Chọn ảnh (OCR) gốc trên Android
class NativeMediaBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.example.thpt_english/native_media',
  );

  /// Gọi hộp thoại nhận diện giọng nói Android gốc ('en-US' hoặc 'vi-VN')
  static Future<String?> recognizeSpeech({
    required String locale,
    String prompt = 'Hãy nói câu cần dịch...',
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('recognizeSpeech', {
        'locale': locale,
        'prompt': prompt,
      });
      return result?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Mở Camera hoặc Thư viện ảnh để lấy ảnh Base64 phục vụ quét OCR
  static Future<String?> pickImageBase64({
    required String source, // 'camera' | 'gallery'
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('pickImageBase64', {
        'source': source,
      });
      if (result != null && result.trim().isNotEmpty) {
        return result.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Mô hình Đề thi có giám sát & Hạn nộp (Supervised Exam)
class SupervisedExamModel {
  final String id;
  final String title;
  final String description;
  final String? classId;
  final String? className;
  final int durationMinutes;
  final DateTime deadlineAt;
  final int graceSeconds;
  final int maxViolations;
  final int maxAttempts;
  final bool shuffleQuestions;
  final String violationAction; // 'force_submit' | 'invalidate'
  final List<Map<String, dynamic>> questions;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  const SupervisedExamModel({
    required this.id,
    required this.title,
    required this.description,
    this.classId,
    this.className,
    required this.durationMinutes,
    required this.deadlineAt,
    this.graceSeconds = 10,
    this.maxViolations = 2,
    this.maxAttempts = 1,
    this.shuffleQuestions = true,
    this.violationAction = 'force_submit',
    required this.questions,
    this.isActive = true,
    this.createdBy = 'teacher',
    required this.createdAt,
  });

  bool get isPastDeadline => DateTime.now().isAfter(deadlineAt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'classId': classId,
    'className': className,
    'durationMinutes': durationMinutes,
    'deadlineAt': deadlineAt.toIso8601String(),
    'graceSeconds': graceSeconds,
    'maxViolations': maxViolations,
    'maxAttempts': maxAttempts,
    'shuffleQuestions': shuffleQuestions,
    'violationAction': violationAction,
    'questions': questions,
    'isActive': isActive,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SupervisedExamModel.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'] ?? map['questions_json'];
    List<Map<String, dynamic>> parsedQuestions = [];
    if (rawQuestions is List) {
      parsedQuestions = rawQuestions
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else if (rawQuestions is String && rawQuestions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawQuestions) as List;
        parsedQuestions = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }

    return SupervisedExamModel(
      id: (map['id'] ?? 'sexam_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      title: (map['title'] ?? 'Đề kiểm tra có giám sát').toString(),
      description: (map['description'] ?? '').toString(),
      classId: (map['classId'] ?? map['class_id'])?.toString(),
      className: (map['className'] ?? map['class_name'])?.toString(),
      durationMinutes:
          (map['durationMinutes'] ?? map['duration_minutes'] as num?)
              ?.toInt() ??
          45,
      deadlineAt:
          DateTime.tryParse(
            (map['deadlineAt'] ?? map['deadline_at'] ?? '').toString(),
          ) ??
          DateTime.now().add(const Duration(days: 7)),
      graceSeconds:
          (map['graceSeconds'] ?? map['grace_seconds'] as num?)?.toInt() ?? 10,
      maxViolations:
          (map['maxViolations'] ?? map['max_violations'] as num?)?.toInt() ?? 2,
      maxAttempts:
          (map['maxAttempts'] ?? map['max_attempts'] as num?)?.toInt() ?? 1,
      shuffleQuestions:
          (map['shuffleQuestions'] ?? map['shuffle_questions']) != false,
      violationAction:
          (map['violationAction'] ?? map['violation_action'] ?? 'force_submit')
              .toString(),
      questions: parsedQuestions,
      isActive: (map['isActive'] ?? map['is_active']) != false,
      createdBy: (map['createdBy'] ?? map['created_by'] ?? 'teacher')
          .toString(),
      createdAt:
          DateTime.tryParse(
            (map['createdAt'] ?? map['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}

/// Mô hình Phiên làm bài & Giám sát trực tiếp của Học viên
class ExamLiveSessionModel {
  final String id;
  final String examId;
  final String userId;
  final String studentName;
  final String studentEmail;
  final String status;
  // 'in_progress' | 'warning_out_of_app' | 'submitted_on_time' | 'submitted_late' | 'force_submitted_auto' | 'force_submitted_teacher' | 'invalidated'
  final int violationCount;
  final List<Map<String, dynamic>> violationLogs;
  final String? teacherWarningMessage;
  final String? studentExplanation;
  final DateTime? explanationSubmittedAt;
  final int answeredCount;
  final int totalQuestions;
  final Map<String, int> currentAnswers;
  final double score;
  final String? aiFeedback;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime lastHeartbeatAt;

  const ExamLiveSessionModel({
    required this.id,
    required this.examId,
    required this.userId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    this.violationCount = 0,
    this.violationLogs = const [],
    this.teacherWarningMessage,
    this.studentExplanation,
    this.explanationSubmittedAt,
    this.answeredCount = 0,
    this.totalQuestions = 0,
    this.currentAnswers = const {},
    this.score = 0.0,
    this.aiFeedback,
    required this.startedAt,
    this.submittedAt,
    required this.lastHeartbeatAt,
  });

  bool get isActive =>
      status == 'in_progress' || status == 'warning_out_of_app';

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'Đang làm bài';
      case 'warning_out_of_app':
        return 'Cảnh báo rời ứng dụng';
      case 'submitted_on_time':
        return 'Nộp đúng hạn';
      case 'submitted_late':
        return 'Nộp trễ hạn';
      case 'force_submitted_auto':
        return 'Thu bài tự động (Vi phạm 10s)';
      case 'force_submitted_teacher':
        return 'Giáo viên thu bài';
      case 'invalidated':
        return 'Hủy kết quả (Gian lận)';
      default:
        return status;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'examId': examId,
    'userId': userId,
    'studentName': studentName,
    'studentEmail': studentEmail,
    'status': status,
    'violationCount': violationCount,
    'violationLogs': violationLogs,
    'teacherWarningMessage': teacherWarningMessage,
    'studentExplanation': studentExplanation,
    'explanationSubmittedAt': explanationSubmittedAt?.toIso8601String(),
    'answeredCount': answeredCount,
    'totalQuestions': totalQuestions,
    'currentAnswers': currentAnswers,
    'score': score,
    'aiFeedback': aiFeedback,
    'startedAt': startedAt.toIso8601String(),
    'submittedAt': submittedAt?.toIso8601String(),
    'lastHeartbeatAt': lastHeartbeatAt.toIso8601String(),
  };

  factory ExamLiveSessionModel.fromMap(Map<String, dynamic> map) {
    final rawLogs = map['violationLogs'] ?? map['violation_logs'];
    List<Map<String, dynamic>> parsedLogs = [];
    if (rawLogs is List) {
      parsedLogs = rawLogs
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    final rawAnswers = map['currentAnswers'] ?? map['current_answers'];
    final Map<String, int> parsedAnswers = {};
    if (rawAnswers is Map) {
      rawAnswers.forEach((k, v) {
        if (v is num) parsedAnswers[k.toString()] = v.toInt();
      });
    }

    return ExamLiveSessionModel(
      id: (map['id'] ?? '').toString(),
      examId: (map['examId'] ?? map['exam_id'] ?? '').toString(),
      userId: (map['userId'] ?? map['user_id'] ?? '').toString(),
      studentName: (map['studentName'] ?? map['student_name'] ?? 'Học viên')
          .toString(),
      studentEmail: (map['studentEmail'] ?? map['student_email'] ?? '')
          .toString(),
      status: (map['status'] ?? 'in_progress').toString(),
      violationCount:
          (map['violationCount'] ?? map['violation_count'] as num?)?.toInt() ??
          0,
      violationLogs: parsedLogs,
      teacherWarningMessage:
          (map['teacherWarningMessage'] ?? map['teacher_warning_message'])
              ?.toString(),
      studentExplanation:
          (map['studentExplanation'] ?? map['student_explanation'])?.toString(),
      explanationSubmittedAt:
          (map['explanationSubmittedAt'] ?? map['explanation_submitted_at']) !=
              null
          ? DateTime.tryParse(
              (map['explanationSubmittedAt'] ?? map['explanation_submitted_at'])
                  .toString(),
            )
          : null,
      answeredCount:
          (map['answeredCount'] ?? map['answered_count'] as num?)?.toInt() ?? 0,
      totalQuestions:
          (map['totalQuestions'] ?? map['total_questions'] as num?)?.toInt() ??
          0,
      currentAnswers: parsedAnswers,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      aiFeedback: (map['aiFeedback'] ?? map['ai_feedback'])?.toString(),
      startedAt:
          DateTime.tryParse(
            (map['startedAt'] ?? map['started_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      submittedAt: (map['submittedAt'] ?? map['submitted_at']) != null
          ? DateTime.tryParse(
              (map['submittedAt'] ?? map['submitted_at']).toString(),
            )
          : null,
      lastHeartbeatAt:
          DateTime.tryParse(
            (map['lastHeartbeatAt'] ?? map['last_heartbeat_at'] ?? '')
                .toString(),
          ) ??
          DateTime.now(),
    );
  }
}

/// Mô hình Lịch Nhắc Hẹn Lớp Học do Giáo viên lên lịch cho Học sinh
class ClassReminderModel {
  final String id;
  final String classId;
  final String className;
  final String title;
  final String message;
  final DateTime scheduledAt;
  final String teacherName;
  final String teacherEmail;
  final DateTime createdAt;
  final bool isActive;

  const ClassReminderModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.title,
    required this.message,
    required this.scheduledAt,
    required this.teacherName,
    required this.teacherEmail,
    required this.createdAt,
    this.isActive = true,
  });

  int get notificationId => id.hashCode.abs() % 100000 + 2000;

  Map<String, dynamic> toMap() => {
    'id': id,
    'classId': classId,
    'className': className,
    'title': title,
    'message': message,
    'scheduledAt': scheduledAt.toIso8601String(),
    'teacherName': teacherName,
    'teacherEmail': teacherEmail,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory ClassReminderModel.fromMap(Map<String, dynamic> map) =>
      ClassReminderModel(
        id: (map['id'] ?? '').toString(),
        classId: (map['classId'] ?? map['class_id'] ?? '').toString(),
        className: (map['className'] ?? map['class_name'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        message: (map['message'] ?? map['content'] ?? '').toString(),
        scheduledAt:
            DateTime.tryParse(
              (map['scheduledAt'] ??
                      map['scheduled_at'] ??
                      map['remind_at'] ??
                      '')
                  .toString(),
            ) ??
            DateTime.now(),
        teacherName:
            (map['teacherName'] ??
                    map['teacher_name'] ??
                    map['sent_by'] ??
                    'Giáo viên')
                .toString(),
        teacherEmail: (map['teacherEmail'] ?? map['teacher_email'] ?? '')
            .toString(),
        createdAt:
            DateTime.tryParse(
              (map['createdAt'] ?? map['created_at'] ?? map['sent_at'] ?? '')
                  .toString(),
            ) ??
            DateTime.now(),
        isActive: map['isActive'] != false && map['status'] != 'cancelled',
      );
}

/// Dịch vụ trung tâm quản lý RBAC (Giáo viên & Admin), Phòng thi Giám sát 10s,
/// Quản lý Phiên bản Sách Giáo Khoa & Trợ lý AI Cá nhân Đa vai trò.
class RbacProctorAiService {
  RbacProctorAiService._();

  static final RbacProctorAiService instance = RbacProctorAiService._();
  String? lastAdminUserError;

  final AppRepository _repo = AppRepository();

  Future<ApiClient> _client() async {
    final token = await _repo.getAuthToken();
    return ApiClient(tokenProvider: () => token);
  }

  // ===========================================================================
  // 1. CẤU HÌNH API KEY CHO TRỢ LÝ AI CHATBOT (Hỗ trợ cả Local + Backend Cloud)
  // ===========================================================================
  Future<Map<String, dynamic>> getAiConfig() async {
    final localKey = await _repo.getSetting('ai_gemini_api_key') ?? '';
    final localModel =
        await _repo.getSetting('ai_gemini_model') ?? 'gemini-2.5-flash';
    final localProvider = await _repo.getSetting('ai_provider') ?? 'gemini';

    try {
      final client = await _client();
      final res = await client.getJson(
        '/admin/ai-config',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data != null) {
        final serverHasKey = res.data!['hasApiKey'] == true;
        return {
          'provider': res.data!['provider'] ?? localProvider,
          'model': res.data!['model'] ?? localModel,
          'hasApiKey': serverHasKey || localKey.isNotEmpty,
          'maskedApiKey': localKey.isNotEmpty
              ? '${localKey.substring(0, localKey.length > 6 ? 6 : localKey.length)}••••••••••••'
              : (res.data!['maskedApiKey'] ?? ''),
          'source': localKey.isNotEmpty
              ? 'Đã cấu hình trực tiếp trên Admin App'
              : (res.data!['source'] ?? 'unconfigured'),
        };
      }
    } catch (_) {}

    return {
      'provider': localProvider,
      'model': localModel,
      'hasApiKey': localKey.isNotEmpty,
      'maskedApiKey': localKey.isNotEmpty
          ? '${localKey.substring(0, localKey.length > 6 ? 6 : localKey.length)}••••••••••••'
          : '',
      'source': localKey.isNotEmpty
          ? 'Đã cấu hình trên thiết bị'
          : 'Chưa cấu hình khóa API (Đang dùng Trợ lý Nội bộ)',
    };
  }

  Future<Map<String, dynamic>> saveAndTestAiConfig({
    required String apiKey,
    required String model,
    String provider = 'gemini',
  }) async {
    final cleanKey = apiKey.trim();
    final cleanModel = model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim();

    if (cleanKey.isNotEmpty) {
      await _repo.setSetting('ai_gemini_api_key', cleanKey);
    }
    await _repo.setSetting('ai_gemini_model', cleanModel);
    await _repo.setSetting('ai_provider', provider);

    await recordAuditLog(
      action: 'UPDATE_AI_CONFIG',
      targetType: 'ai_config',
      targetId: cleanModel,
      details: 'Cập nhật cấu hình AI Chatbot ($provider - $cleanModel)',
    );

    // Kiểm tra kết nối trực tiếp tới Google Gemini API nếu có key
    final effectiveKey = cleanKey.isNotEmpty
        ? cleanKey
        : (await _repo.getSetting('ai_gemini_api_key') ?? '');

    bool verified = false;
    String testReply = '';

    if (effectiveKey.isNotEmpty) {
      final directTest = await _callDirectGemini(
        apiKey: effectiveKey,
        model: cleanModel,
        systemInstruction: 'Trả lời 1 câu ngắn bằng tiếng Việt.',
        userPrompt: 'Xin chào, xác nhận kết nối EngPass AI thành công!',
      );
      if (directTest != null && directTest.isNotEmpty) {
        verified = true;
        testReply = directTest;
      }
    }

    // Đồng bộ lên Backend nếu có mạng
    try {
      final client = await _client();
      await client.putJson('/admin/ai-config', {
        if (cleanKey.isNotEmpty) 'apiKey': cleanKey,
        'model': cleanModel,
        'provider': provider,
        'testConnection': true,
      }, timeout: const Duration(seconds: 8));
    } catch (_) {}

    return {
      'success': true,
      'verified': verified,
      'model': cleanModel,
      'testReply': verified
          ? testReply
          : (effectiveKey.isEmpty
                ? 'Đã lưu cấu hình. Hiện chưa nhập API Key nên hệ thống sử dụng Bộ xử lý Học thuật Nội bộ.'
                : 'Đã lưu API Key. Vui lòng kiểm tra lại kết nối mạng hoặc mã khóa nếu cần gọi trực tuyến.'),
    };
  }

  Future<String?> _callDirectGemini({
    required String apiKey,
    required String model,
    required String systemInstruction,
    required String userPrompt,
    String? imageBase64,
  }) async {
    final models = <String>{
      model,
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    }.toList();

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      for (final m in models) {
        try {
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$apiKey',
          );
          final req = await httpClient
              .postUrl(uri)
              .timeout(const Duration(seconds: 12));
          req.headers.set('Content-Type', 'application/json; charset=utf-8');

          final parts = <Map<String, dynamic>>[
            {'text': userPrompt},
          ];
          if (imageBase64 != null && imageBase64.isNotEmpty) {
            final cleanB64 = imageBase64.replaceFirst(
              RegExp(r'^data:image/\w+;base64,'),
              '',
            );
            parts.add({
              'inline_data': {'mime_type': 'image/jpeg', 'data': cleanB64},
            });
          }

          req.write(
            jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': systemInstruction},
                ],
              },
              'contents': [
                {'parts': parts},
              ],
            }),
          );

          final res = await req.close().timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final decoded = jsonDecode(body) as Map<String, dynamic>;
            final candidates = decoded['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'] as Map<String, dynamic>?;
              final cParts = content?['parts'] as List?;
              if (cParts != null && cParts.isNotEmpty) {
                final text = cParts[0]['text']?.toString();
                if (text != null && text.trim().isNotEmpty) {
                  return text.trim();
                }
              }
            }
          }
        } catch (_) {}
      }
    } finally {
      httpClient.close();
    }
    return null;
  }

  // ===========================================================================
  // 2. TRỢ LÝ AI CHATBOT ĐA VAI TRÒ (Học viên / Giáo viên / Admin)
  // ===========================================================================
  Future<Map<String, dynamic>> askRoleCopilot({
    required String role, // 'student' | 'teacher' | 'admin'
    required String
    mode, // 'general' | 'writing_check' | 'exam_explain' | 'teacher_assist' | 'admin_assist'
    required String message,
    int? unitNumber,
    String? contextText,
  }) async {
    // RÀNG BUỘC 1: Khóa tuyệt đối khi học viên đang trong Phòng thi có giám sát
    if (role == 'student' && ExamLockGuard.instance.isLocked) {
      return {
        'isLocked': true,
        'answer':
            '🔒 **Tính năng Trợ lý AI đang bị khóa tạm thời!**\n\n'
            'Bạn đang trong Phòng thi có giám sát: **"${ExamLockGuard.instance.activeExamTitle ?? "Kiểm tra định kỳ"}"**.\n'
            'Để đảm bảo công bằng, mọi công cụ AI và Dịch thuật chỉ mở lại sau khi bạn nộp bài.',
      };
    }

    final localKey = await _repo.getSetting('ai_gemini_api_key') ?? '';
    final localModel =
        await _repo.getSetting('ai_gemini_model') ?? 'gemini-2.5-flash';

    final systemInstruction = _buildRoleSystemPrompt(role, mode, unitNumber);

    // 1. Nếu đã cấu hình API Key trên ứng dụng -> Gọi trực tiếp Gemini tốc độ cao
    if (localKey.isNotEmpty) {
      final reply = await _callDirectGemini(
        apiKey: localKey,
        model: localModel,
        systemInstruction: systemInstruction,
        userPrompt: contextText != null && contextText.isNotEmpty
            ? 'Ngữ cảnh: $contextText\n\nYêu cầu: $message'
            : message,
      );
      if (reply != null) {
        return {
          'isAvailable': true,
          'source': 'Google Gemini ($localModel)',
          'answer': reply,
        };
      }
    }

    // 2. Gọi qua Backend API
    try {
      final client = await _client();
      final res = await client.postJson('/ai/chat', {
        'message': message,
        'roleContext': role,
        'mode': mode,
        'unitNumber': unitNumber,
        'contextText': contextText,
      }, timeout: const Duration(seconds: 12));

      if (res.statusCode == 403 && res.data?['examLocked'] == true) {
        return {
          'isLocked': true,
          'answer':
              res.errorMessage ??
              '🔒 Tính năng AI bị khóa khi đang làm bài thi có giám sát.',
        };
      }

      if (res.isSuccess && res.data != null && res.data!['answer'] != null) {
        return {
          'isAvailable': res.data!['isAvailable'] == true,
          'source': res.data!['isAvailable'] == true
              ? 'Cloud AI Backend'
              : 'Trợ lý Học thuật Nội bộ',
          'answer': res.data!['answer'].toString(),
        };
      }
    } catch (_) {}

    // 3. Fallback Học thuật Thông minh theo từng vai trò
    return {
      'isAvailable': false,
      'source': 'Trợ lý Học thuật Nội bộ SGK 12',
      'answer': _buildSmartLocalCopilotReply(
        role: role,
        mode: mode,
        message: message,
        unitNumber: unitNumber,
      ),
    };
  }

  String _buildRoleSystemPrompt(String role, String mode, int? unitNumber) {
    if (role == 'admin') {
      return 'Bạn là Trợ lý Quản trị Hệ thống & Số hóa Học liệu (Admin AI Copilot) của EngPass Tiếng Anh 12. '
          'Hỗ trợ Admin chuẩn hóa nội dung bài học SGK mới, kiểm tra dữ liệu và phân tích nhật ký hệ thống. '
          'RÀNG BUỘC: Không tự ý xóa dữ liệu hay khóa tài khoản nếu Admin chưa xác nhận.';
    }
    if (role == 'teacher') {
      return 'Bạn là Trợ lý Soạn giảng & Chấm bài (Teacher AI Copilot) cho Giáo viên Tiếng Anh 12 THPT. '
          'Hỗ trợ tạo câu hỏi trắc nghiệm 4 đáp án A/B/C/D kèm giải thích, chấm bài và nhận xét kết quả học sinh, soạn tài liệu lớp học.';
    }
    if (mode == 'writing_check') {
      return 'Bạn là Giám khảo Chấm câu & Đoạn văn Tiếng Anh THPT Quốc gia. '
          'Hãy chấm điểm trên thang 10, chỉ rõ lỗi ngữ pháp/từ vựng, giải thích ngắn gọn bằng tiếng Việt và đưa ra 1 phiên bản viết lại nâng cao.';
    }
    return 'Bạn là Gia sư AI Cá nhân Tiếng Anh 12 Global Success (Unit ${unitNumber ?? "1-10"}). '
        'RÀNG BUỘC SƯ PHẠM: Giải thích từ vựng (kèm IPA), cấu trúc ngữ pháp dễ hiểu và hướng dẫn cách tư duy loại trừ đáp án (Socratic), không làm bài hộ máy móc.';
  }

  String _buildSmartLocalCopilotReply({
    required String role,
    required String mode,
    required String message,
    int? unitNumber,
  }) {
    final q = message.trim();
    if (role == 'admin') {
      return '🛡️ **[Trợ lý AI Quản trị viên – EngPass Copilot]**\n\n'
          '• **Yêu cầu của Admin:** *"$q"*\n'
          '• **Trạng thái kết nối:** Hiện chưa kết nối được với máy chủ AI trực tuyến (Render). Vui lòng kiểm tra kết nối mạng hoặc biến môi trường `GEMINI_API_KEY` trên Render.\n'
          '• **Công cụ quản trị dữ liệu thật:** Bạn có thể sử dụng trực tiếp mục **Nội dung** để quản lý 10 Unit SGK, **Người dùng** để duyệt giáo viên và **Quản lý** để giám sát lớp học & kỳ thi.';
    }
    if (role == 'teacher') {
      return '👩‍🏫 **[Trợ lý AI Giáo viên – Soạn giảng & Chấm bài]**\n\n'
          '• **Yêu cầu của Giáo viên:** *"$q"*\n'
          '• **Trạng thái kết nối:** Hiện đang ở chế độ ngoại tuyến. Bạn có thể trích xuất câu hỏi trực tiếp từ Ngân hàng câu hỏi thật của 10 Unit SGK Lớp 12 hoặc kết nối mạng để gọi Gemini AI.';
    }
    if (mode == 'writing_check') {
      return '📝 **[Trợ lý Chấm bài viết AI]**\n\n'
          '• **Bài viết của bạn:** *"$q"*\n'
          '• **Thông báo:** Tính năng chấm điểm và sửa lỗi bài viết chi tiết yêu cầu kết nối trực tuyến tới máy chủ AI Gemini trên Render. Vui lòng kiểm tra kết nối mạng và thử lại.';
    }

    // Tra cứu thực tế từ điển học liệu SGK 12 nếu học sinh hỏi từ/cụm từ
    final lesson = unitNumber != null
        ? TrialLessonRepository.instance.getLessonByUnit(unitNumber)
        : TrialLessonRepository.instance.getDefaultLesson();
    final lookup = TrialLessonRepository.instance.lookupWordOrPhrase(
      query: q,
      currentLesson: lesson,
    );
    if (lookup.isFoundInDictionary) {
      return '🎓 **[Tra cứu Học liệu SGK Tiếng Anh 12${unitNumber != null ? " – Unit $unitNumber" : ""}]**\n\n'
          '• **Từ/Cụm từ:** **${lookup.displayWord}** ${lookup.phonetic ?? ""} ${lookup.partOfSpeech ?? ""}\n'
          '• **Nghĩa chuẩn SGK:** ${lookup.meaning}\n'
          '• **Nguồn:** ${lookup.source}';
    }

    return '🎓 **[Gia sư AI Cá nhân – SGK Tiếng Anh 12${unitNumber != null ? " Unit $unitNumber" : ""}]**\n\n'
        '• **Câu hỏi của bạn:** *"$q"*\n'
        '• **Thông báo:** Hiện thiết bị đang ngoại tuyến hoặc máy chủ AI đang bận. Bạn có thể tra cứu trực tiếp từ vựng/ngữ pháp trong mục **Sách** hoặc kết nối mạng để trò chuyện trực tuyến với AI.';
  }

  /// Sinh câu hỏi trắc nghiệm bằng AI cho Giáo viên & Admin (hoặc trích xuất từ Ngân hàng câu hỏi thật trong DB)
  Future<List<Map<String, dynamic>>> generateQuestionsWithAi({
    required int unitNumber,
    required String skill,
    required int difficulty,
    required int count,
    String topicPrompt = '',
  }) async {
    final localKey = await _repo.getSetting('ai_gemini_api_key') ?? '';
    final localModel =
        await _repo.getSetting('ai_gemini_model') ?? 'gemini-2.5-flash';

    if (localKey.isNotEmpty) {
      final prompt =
          'Tạo $count câu hỏi trắc nghiệm Tiếng Anh lớp 12 (Global Success) cho Unit $unitNumber, '
          'kỹ năng "$skill", độ khó $difficulty/3. Yêu cầu thêm: ${topicPrompt.isEmpty ? "Chuẩn thi THPT" : topicPrompt}. '
          'Chỉ trả về JSON Array thuần túy: [{"stem":"...","options":["A. ...","B. ...","C. ...","D. ..."],"correctIndex":0,"explanation":"..."}]';
      final raw = await _callDirectGemini(
        apiKey: localKey,
        model: localModel,
        systemInstruction: 'Chỉ trả về JSON Array hợp lệ, không bọc markdown.',
        userPrompt: prompt,
      );
      if (raw != null) {
        try {
          final cleaned = raw
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();
          final decoded = jsonDecode(cleaned) as List;
          return decoded.asMap().entries.map((entry) {
            final m = Map<String, dynamic>.from(entry.value as Map);
            return {
              'id':
                  'ai_q_${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
              'unitNumber': unitNumber,
              'skill': skill,
              'difficulty': difficulty,
              'stem': (m['stem'] ?? '').toString(),
              'options':
                  (m['options'] as List?)?.map((e) => e.toString()).toList() ??
                  ['A. Đáp án 1', 'B. Đáp án 2', 'C. Đáp án 3', 'D. Đáp án 4'],
              'correctIndex': (m['correctIndex'] as num?)?.toInt() ?? 0,
              'explanation': (m['explanation'] ?? '').toString(),
            };
          }).toList();
        } catch (_) {}
      }
    }

    try {
      final client = await _client();
      final res = await client.postJson('/ai/generate-questions', {
        'unitNumber': unitNumber,
        'skill': skill,
        'difficulty': difficulty,
        'count': count,
        'topicPrompt': topicPrompt,
      }, timeout: const Duration(seconds: 12));
      if (res.isSuccess && res.data?['questions'] is List) {
        return (res.data!['questions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}

    // Truy vấn trực tiếp từ Ngân hàng câu hỏi thật trong SQLite & Học liệu SGK 12 thật
    return _loadRealQuestionsFromBank(
      unitNumber,
      skill,
      difficulty,
      count,
      topicPrompt,
    );
  }

  Future<List<Map<String, dynamic>>> _loadRealQuestionsFromBank(
    int unitNumber,
    String skill,
    int difficulty,
    int count,
    String topicPrompt,
  ) async {
    final dbQuestions = await getTeacherQuestions(
      unitNumber: unitNumber,
      skill: skill == 'all' ? null : skill,
    );
    final pool = <Question>[...dbQuestions];

    if (pool.isEmpty) {
      final allUnitQuestions = await getTeacherQuestions(
        unitNumber: unitNumber,
      );
      pool.addAll(allUnitQuestions);
    }

    if (pool.isEmpty) {
      final lesson =
          TrialLessonRepository.instance.getLessonByUnit(unitNumber) ??
          TrialLessonRepository.instance.getDefaultLesson();
      pool.addAll(lesson.questionsAsStandardQuestions);
    }

    if (pool.isEmpty) {
      pool.addAll(
        TrialLessonRepository.instance.getAllReadyStandardQuestions(),
      );
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < count && pool.isNotEmpty; i++) {
      final item = pool[i % pool.length];
      out.add({
        'id':
            'q_bank_${unitNumber}_${DateTime.now().millisecondsSinceEpoch}_$i',
        'unitNumber': unitNumber,
        'skill': skill.isNotEmpty ? skill : item.type,
        'difficulty': difficulty,
        'stem': item.stem,
        'options': List<String>.from(item.options),
        'correctIndex': item.correctIndex,
        'explanation':
            '${item.explanation}${topicPrompt.isNotEmpty ? " ($topicPrompt)" : ""}',
      });
    }
    return out;
  }

  /// Số hóa văn bản sách giáo khoa mới thành gói dữ liệu Bài học chuẩn cho Admin
  Future<Map<String, dynamic>> digitizeCurriculumWithAi({
    required int unitNumber,
    required String title,
    required String rawText,
  }) async {
    try {
      final client = await _client();
      final res = await client.postJson('/ai/digitize-curriculum', {
        'unitNumber': unitNumber,
        'title': title,
        'rawText': rawText,
      }, timeout: const Duration(seconds: 15));
      if (res.isSuccess && res.data?['digitizedUnit'] is Map) {
        return Map<String, dynamic>.from(res.data!['digitizedUnit'] as Map);
      }
    } catch (_) {}

    // Đối chiếu từ vựng thực tế từ bảng `words` của SQLite và từ điển SGK 12
    final clean = rawText.trim();
    final db = await AppDatabase.instance.database;
    final existingWordsRows = await db.query(
      'words',
      where: 'topicId = ?',
      whereArgs: ['t$unitNumber'],
    );
    final dbWordsMap = <String, Word>{};
    for (final r in existingWordsRows) {
      final w = Word.fromMap(r);
      dbWordsMap[w.english.toLowerCase()] = w;
    }

    final lesson = TrialLessonRepository.instance.getLessonByUnit(unitNumber);
    final tokens = clean
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet()
        .toList();

    final vocabList = <Map<String, dynamic>>[];
    for (final token in tokens) {
      if (vocabList.length >= 8) break;
      if (dbWordsMap.containsKey(token)) {
        final w = dbWordsMap[token]!;
        vocabList.add({
          'english': w.english,
          'ipa': w.ipa,
          'meaningVi': w.meaningVi,
          'example': w.example,
        });
        continue;
      }
      final lookedUp = TrialLessonRepository.instance.lookupWordOrPhrase(
        query: token,
        currentLesson: lesson,
      );
      if (lookedUp.isFoundInDictionary) {
        vocabList.add({
          'english': token,
          'ipa': lookedUp.phonetic ?? '',
          'meaningVi': lookedUp.meaning,
          'example': lookedUp.contextSentence ?? '',
        });
      }
    }

    if (vocabList.isEmpty && dbWordsMap.isNotEmpty) {
      for (final w in dbWordsMap.values.take(6)) {
        vocabList.add({
          'english': w.english,
          'ipa': w.ipa,
          'meaningVi': w.meaningVi,
          'example': w.example,
        });
      }
    }

    if (vocabList.isEmpty && lesson != null) {
      for (final entry in lesson.vocabulary.entries.take(6)) {
        final lookedUp = TrialLessonRepository.instance.lookupWordOrPhrase(
          query: entry.key,
          currentLesson: lesson,
        );
        vocabList.add({
          'english': entry.key,
          'ipa': lookedUp.phonetic ?? '',
          'meaningVi': entry.value,
          'example': '',
        });
      }
    }

    final questions = await _loadRealQuestionsFromBank(
      unitNumber,
      'reading',
      2,
      4,
      title,
    );

    return {
      'unitNumber': unitNumber,
      'title': title.isNotEmpty
          ? title
          : (lesson?.unitTitle ?? 'Unit $unitNumber - Chương trình SGK 12'),
      'readingPassage': clean,
      'translationVi': lesson != null && lesson.paragraphs.isNotEmpty
          ? lesson.paragraphs.map((p) => p.translation).join('\n\n')
          : '',
      'grammarSummary':
          lesson?.lessonTitle ?? 'Nội dung bài học Unit $unitNumber',
      'vocabulary': vocabList,
      'questions': questions,
    };
  }

  // ===========================================================================
  // 3. QUẢN LÝ NGÂN HÀNG CÂU HỎI & TÀI LIỆU CỦA GIÁO VIÊN / ADMIN (FULL CRUD)
  // ===========================================================================
  Future<List<Question>> getTeacherQuestions({
    int? unitNumber,
    String? skill,
  }) async {
    final db = await AppDatabase.instance.database;
    String where = '1=1';
    final args = <Object?>[];
    if (unitNumber != null) {
      where += ' AND topicId = ?';
      args.add('t$unitNumber');
    }
    if (skill != null && skill.isNotEmpty && skill != 'all') {
      where += ' AND type = ?';
      args.add(skill);
    }
    final rows = await db.query(
      'questions',
      where: where,
      whereArgs: args,
      orderBy: 'rowid DESC',
      limit: 150,
    );
    return rows.map((r) => Question.fromMap(r)).toList();
  }

  Future<void> saveTeacherQuestion({
    String? id,
    required int unitNumber,
    required String skill,
    required int difficulty,
    required String stem,
    required List<String> options,
    required int correctIndex,
    required String explanation,
  }) async {
    await saveTeacherQuestions([
      {
        'id': ?id,
        'unitNumber': unitNumber,
        'skill': skill,
        'difficulty': difficulty,
        'stem': stem,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      },
    ]);
  }

  Future<void> saveTeacherQuestions(
    List<Map<String, dynamic>> rawQuestions,
  ) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final q in rawQuestions) {
      final qId = (q['id'] ?? 'tq_${DateTime.now().millisecondsSinceEpoch}')
          .toString();
      final unitNum = (q['unitNumber'] as num?)?.toInt() ?? 1;
      final options =
          (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if ((q['stem'] ?? '').toString().trim().isEmpty || options.length < 2)
        continue;

      final questionObj = Question(
        id: qId,
        grade: 12,
        type: (q['skill'] ?? q['type'] ?? 'grammar').toString(),
        stem: q['stem'].toString().trim(),
        options: options,
        correctIndex: (q['correctIndex'] as num?)?.toInt() ?? 0,
        explanation: (q['explanation'] ?? '').toString().trim(),
        topicId: 't$unitNum',
        difficulty: (q['difficulty'] as num?)?.toInt() ?? 2,
      );
      batch.insert(
        'questions',
        questionObj.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    await recordAuditLog(
      action: 'SAVE_QUESTIONS',
      targetType: 'questions',
      targetId: '${rawQuestions.length}_items',
      details: 'Lưu ${rawQuestions.length} câu hỏi vào Ngân hàng câu hỏi',
    );

    try {
      final client = await _client();
      await client.postJson('/teacher/questions', {'questions': rawQuestions});
    } catch (_) {}
  }

  Future<void> deleteTeacherQuestion(String questionId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('questions', where: 'id = ?', whereArgs: [questionId]);
    await recordAuditLog(
      action: 'DELETE_QUESTION',
      targetType: 'questions',
      targetId: questionId,
      details: 'Xóa câu hỏi $questionId khỏi Ngân hàng đề',
    );
    try {
      final client = await _client();
      await client.deleteJson('/teacher/questions/$questionId');
    } catch (_) {}
  }

  // Quản lý Tài liệu & Bài học bổ trợ (Study Materials CRUD - Không tự tạo dữ liệu giả)
  Future<List<Map<String, dynamic>>> getStudyMaterials() async {
    final raw = await _repo.getSetting('teacher_study_materials_json');
    List<Map<String, dynamic>> localList = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        localList = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }
    try {
      final client = await _client();
      final res = await client.getJson(
        '/teacher/materials',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data?['materials'] is List) {
        final serverList = (res.data!['materials'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (serverList.isNotEmpty) {
          for (final sMat in serverList) {
            if (!localList.any((l) => l['id'] == sMat['id'])) {
              localList.add(sMat);
            }
          }
          await _repo.setSetting(
            'teacher_study_materials_json',
            jsonEncode(localList),
          );
        }
      }
    } catch (_) {}
    return localList;
  }

  Future<void> saveStudyMaterial(Map<String, dynamic> material) async {
    final list = await getStudyMaterials();
    final id =
        (material['id'] ?? 'mat_${DateTime.now().millisecondsSinceEpoch}')
            .toString();
    final updatedItem = {
      ...material,
      'id': id,
      'createdAt': material['createdAt'] ?? DateTime.now().toIso8601String(),
    };
    final idx = list.indexWhere((m) => m['id'] == id);
    if (idx >= 0) {
      list[idx] = updatedItem;
    } else {
      list.insert(0, updatedItem);
    }
    await _repo.setSetting('teacher_study_materials_json', jsonEncode(list));
    await recordAuditLog(
      action: idx >= 0 ? 'UPDATE_MATERIAL' : 'CREATE_MATERIAL',
      targetType: 'study_material',
      targetId: id,
      details: 'Cập nhật tài liệu học tập: ${updatedItem['title']}',
    );
    try {
      final client = await _client();
      await client.postJson('/teacher/materials', updatedItem);
    } catch (_) {}
  }

  Future<void> deleteStudyMaterial(String id) async {
    final list = await getStudyMaterials();
    list.removeWhere((m) => m['id'] == id);
    await _repo.setSetting('teacher_study_materials_json', jsonEncode(list));
    await recordAuditLog(
      action: 'DELETE_MATERIAL',
      targetType: 'study_material',
      targetId: id,
      details: 'Xóa tài liệu lớp học $id',
    );
    try {
      final client = await _client();
      await client.deleteJson('/teacher/materials/$id');
    } catch (_) {}
  }

  // ===========================================================================
  // 4. QUẢN LÝ PHÒNG THI CÓ GIÁM SÁT & CHỐNG GIAN LẬN 10 GIÂY (EXAMS & PROCTORING)
  // ===========================================================================
  Future<List<SupervisedExamModel>> getSupervisedExams() async {
    final raw = await _repo.getSetting('supervised_exams_json');
    List<SupervisedExamModel> localExams = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        localExams = decoded
            .map(
              (e) => SupervisedExamModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}
    }

    // Tự động kích hoạt đồng bộ các bài thi ở local lên Cloud
    if (localExams.isNotEmpty) {
      unawaited(syncAllSupervisedExamsToCloud());
    }

    // Đồng bộ từ Backend nếu có mạng
    try {
      final client = await _client();
      final res = await client.getJson(
        '/exams/supervised',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data?['exams'] is List) {
        final serverList = (res.data!['exams'] as List)
            .map(
              (e) => SupervisedExamModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        if (serverList.isNotEmpty) {
          for (final sExam in serverList) {
            final idx = localExams.indexWhere((l) => l.id == sExam.id);
            if (idx >= 0) {
              localExams[idx] = sExam;
            } else {
              localExams.add(sExam);
            }
          }
          await _saveSupervisedExamsLocal(localExams);
        }
      }
    } catch (_) {}

    return localExams;
  }

  /// Đồng bộ toàn bộ các kỳ thi giám sát lưu cục bộ lên Cloud Render
  Future<Map<String, dynamic>> syncAllSupervisedExamsToCloud() async {
    final raw = await _repo.getSetting('supervised_exams_json');
    if (raw == null || raw.isEmpty) return {'syncedCount': 0};
    try {
      final decoded = jsonDecode(raw) as List;
      if (decoded.isEmpty) return {'syncedCount': 0};
      final client = await _client();
      final res = await client.postJson('/teacher/exams/batch-sync', {
        'exams': decoded,
      }, timeout: const Duration(seconds: 10));
      if (res.isSuccess && res.data != null) {
        return res.data!;
      }
    } catch (_) {}
    return {'syncedCount': 0};
  }

  Future<void> _saveSupervisedExamsLocal(
    List<SupervisedExamModel> exams,
  ) async {
    await _repo.setSetting(
      'supervised_exams_json',
      jsonEncode(exams.map((e) => e.toMap()).toList()),
    );
  }

  Future<SupervisedExamModel> saveSupervisedExam({
    String? id,
    required String title,
    required String description,
    String? classId,
    String? className,
    required int durationMinutes,
    required DateTime deadlineAt,
    required int graceSeconds,
    required int maxViolations,
    int maxAttempts = 1,
    bool shuffleQuestions = true,
    required String violationAction,
    List<Map<String, dynamic>>? questions,
    bool isActive = true,
  }) async {
    final exams = await getSupervisedExams();
    final examId = id ?? 'sexam_${DateTime.now().millisecondsSinceEpoch}';
    final finalQuestions = (questions != null && questions.isNotEmpty)
        ? questions
        : await _loadRealQuestionsFromBank(1, 'grammar', 2, 10, title);

    final model = SupervisedExamModel(
      id: examId,
      title: title.trim(),
      description: description.trim(),
      classId: classId,
      className: className,
      durationMinutes: durationMinutes,
      deadlineAt: deadlineAt,
      graceSeconds: graceSeconds,
      maxViolations: maxViolations,
      maxAttempts: maxAttempts,
      shuffleQuestions: shuffleQuestions,
      violationAction: violationAction,
      questions: finalQuestions,
      isActive: isActive,
      createdAt: DateTime.now(),
    );

    final idx = exams.indexWhere((e) => e.id == examId);
    if (idx >= 0) {
      exams[idx] = model;
    } else {
      exams.insert(0, model);
    }
    await _saveSupervisedExamsLocal(exams);

    await recordAuditLog(
      action: idx >= 0 ? 'UPDATE_SUPERVISED_EXAM' : 'CREATE_SUPERVISED_EXAM',
      targetType: 'supervised_exam',
      targetId: examId,
      details:
          'Cấu hình đề thi giám sát "$title" (Ân hạn: ${graceSeconds}s, Vi phạm tối đa: $maxViolations lần)',
    );

    try {
      final client = await _client();
      final res = await client.postJson('/teacher/exams', model.toMap());
      if (res.isSuccess && res.data?['exam'] is Map) {
        final serverExam = SupervisedExamModel.fromMap(
          Map<String, dynamic>.from(res.data!['exam'] as Map),
        );
        final sIdx = exams.indexWhere(
          (e) => e.id == serverExam.id || e.id == examId,
        );
        if (sIdx >= 0) {
          exams[sIdx] = serverExam;
        } else {
          exams.insert(0, serverExam);
        }
        await _saveSupervisedExamsLocal(exams);
        return serverExam;
      }
    } catch (_) {}

    unawaited(syncAllSupervisedExamsToCloud());

    return model;
  }

  Future<void> deleteSupervisedExam(String examId) async {
    final exams = await getSupervisedExams();
    exams.removeWhere((e) => e.id == examId);
    await _saveSupervisedExamsLocal(exams);
    await recordAuditLog(
      action: 'DELETE_SUPERVISED_EXAM',
      targetType: 'supervised_exam',
      targetId: examId,
      details: 'Xóa đề thi giám sát $examId',
    );
    try {
      final client = await _client();
      await client.deleteJson('/teacher/exams/$examId');
    } catch (_) {}
  }

  /// Lấy danh sách các phiên làm bài trực tiếp của 1 đề thi (Dành cho Bảng Giám sát Giáo viên)
  Future<List<ExamLiveSessionModel>> getLiveSessionsForExam(
    String examId,
  ) async {
    final raw = await _repo.getSetting('exam_live_sessions_json');
    List<ExamLiveSessionModel> all = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        all = decoded
            .map(
              (e) => ExamLiveSessionModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}
    }
    return all.where((s) => s.examId == examId).toList();
  }

  Future<void> _saveLiveSession(ExamLiveSessionModel session) async {
    final raw = await _repo.getSetting('exam_live_sessions_json');
    List<ExamLiveSessionModel> all = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        all = decoded
            .map(
              (e) => ExamLiveSessionModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}
    }
    final idx = all.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.insert(0, session);
    }
    await _repo.setSetting(
      'exam_live_sessions_json',
      jsonEncode(all.map((e) => e.toMap()).toList()),
    );
  }

  /// Học sinh bắt đầu vào Phòng thi có giám sát
  Future<ExamLiveSessionModel> startSupervisedExamSession({
    required SupervisedExamModel exam,
    required String userId,
    required String studentName,
    required String studentEmail,
  }) async {
    // 1. Kiểm tra nếu học sinh đã hoàn tất bài thi này (nộp bài hoặc bị thu bài do vi phạm)
    final existingList = await getLiveSessionsForExam(exam.id);
    final completedSession = existingList
        .where((s) => s.userId == userId && !s.isActive)
        .firstOrNull;
    if (completedSession != null) {
      ExamLockGuard.instance.exitSupervisedExam();
      return completedSession;
    }

    // 2. Nếu đang có phiên thi dở dang (ví dụ bị ngắt nguồn, crash app), tiếp tục phiên đó
    final runningSession = existingList
        .where((s) => s.userId == userId && s.isActive)
        .firstOrNull;
    if (runningSession != null) {
      ExamLockGuard.instance.enterSupervisedExam(
        examId: exam.id,
        examTitle: exam.title,
      );
      return runningSession;
    }

    // 3. Nếu chưa từng thi: Khởi tạo phiên thi mới
    ExamLockGuard.instance.enterSupervisedExam(
      examId: exam.id,
      examTitle: exam.title,
    );

    final session = ExamLiveSessionModel(
      id: 'ses_${DateTime.now().millisecondsSinceEpoch}',
      examId: exam.id,
      userId: userId,
      studentName: studentName,
      studentEmail: studentEmail,
      status: 'in_progress',
      totalQuestions: exam.questions.length,
      startedAt: DateTime.now(),
      lastHeartbeatAt: DateTime.now(),
    );
    await _saveLiveSession(session);

    try {
      final client = await _client();
      final res = await client.postJson(
        '/exams/supervised/${exam.id}/start',
        {},
      );
      if (res.statusCode == 403 && res.data?['isLocked'] == true) {
        ExamLockGuard.instance.exitSupervisedExam();
        final reason =
            res.data?['lockedReason']?.toString() ??
            'Tài khoản đã bị tạm khóa.';
        throw Exception('ACCOUNT_LOCKED:$reason');
      }
    } catch (e) {
      if (e.toString().contains('ACCOUNT_LOCKED')) rethrow;
    }

    return session;
  }

  /// Ghi nhận sự kiện vi phạm (rời ứng dụng / mất tiêu điểm) hoặc cập nhật tiến độ
  Future<ExamLiveSessionModel> recordProctorHeartbeat({
    required SupervisedExamModel exam,
    required ExamLiveSessionModel currentSession,
    required Map<String, int> currentAnswers,
    required String
    eventType, // 'heartbeat' | 'app_backgrounded' | 'app_resumed' | 'timeout_10s_exceeded'
    int outOfAppSeconds = 0,
    String detail = '',
  }) async {
    // Kiểm tra xem Giáo viên có vừa can thiệp (Thu bài / Hủy bài / Nhắc nhở) trên máy không
    final existingList = await getLiveSessionsForExam(exam.id);
    final latestSaved =
        existingList.where((s) => s.id == currentSession.id).firstOrNull ??
        currentSession;
    if (!latestSaved.isActive) {
      ExamLockGuard.instance.exitSupervisedExam();
      return latestSaved;
    }

    int newViolations = latestSaved.violationCount;
    final logs = List<Map<String, dynamic>>.from(latestSaved.violationLogs);
    String newStatus = 'in_progress';
    String? warnMsg = latestSaved.teacherWarningMessage;
    bool autoTerminate = false;

    if (eventType == 'app_backgrounded') {
      newViolations += 1;
      newStatus = 'warning_out_of_app';
      logs.add({
        'type': 'OUT_OF_APP',
        'timestamp': DateTime.now().toIso8601String(),
        'detail': detail.isNotEmpty
            ? detail
            : 'Rời khỏi màn hình thi (Mở đa nhiệm / Chuyển ứng dụng ngoài).',
        'violationNumber': newViolations,
      });
      if (newViolations > exam.maxViolations) {
        autoTerminate = true;
        warnMsg =
            'Hệ thống tự động xử lý: Bạn đã rời ứng dụng $newViolations lần (vượt quá giới hạn ${exam.maxViolations} lần).';
      }
    } else if (eventType == 'timeout_10s_exceeded' ||
        outOfAppSeconds >= exam.graceSeconds) {
      newViolations += 1;
      logs.add({
        'type': 'EXCEEDED_GRACE_TIME',
        'timestamp': DateTime.now().toIso8601String(),
        'outOfAppSeconds': outOfAppSeconds,
        'detail':
            'Rời ứng dụng quá ${exam.graceSeconds} giây không quay lại làm bài.',
      });
      autoTerminate = true;
      warnMsg =
          'Hệ thống tự động xử lý: Bạn đã rời khỏi ứng dụng quá ${exam.graceSeconds} giây quy định của phòng thi.';
    }

    double finalScore = latestSaved.score;
    DateTime? submittedAt = latestSaved.submittedAt;

    if (autoTerminate) {
      newStatus = exam.violationAction == 'invalidate'
          ? 'invalidated'
          : 'force_submitted_auto';
      finalScore = newStatus == 'invalidated'
          ? 0.0
          : _computeExamScore(exam.questions, currentAnswers);
      submittedAt = DateTime.now();
      ExamLockGuard.instance.exitSupervisedExam();

      await recordAuditLog(
        action: 'AUTO_ANTI_CHEAT_SUBMIT',
        targetType: 'exam_live_session',
        targetId: currentSession.id,
        details: '${currentSession.studentName} bị $newStatus ($warnMsg)',
      );
    }

    final updated = ExamLiveSessionModel(
      id: currentSession.id,
      examId: exam.id,
      userId: currentSession.userId,
      studentName: currentSession.studentName,
      studentEmail: currentSession.studentEmail,
      status: newStatus,
      violationCount: newViolations,
      violationLogs: logs,
      teacherWarningMessage: warnMsg,
      answeredCount: currentAnswers.length,
      totalQuestions: exam.questions.length,
      currentAnswers: currentAnswers,
      score: finalScore,
      startedAt: currentSession.startedAt,
      submittedAt: submittedAt,
      lastHeartbeatAt: DateTime.now(),
    );

    await _saveLiveSession(updated);

    try {
      final client = await _client();
      await client.postJson('/exams/supervised/${exam.id}/heartbeat', {
        'sessionId': currentSession.id,
        'currentAnswers': currentAnswers,
        'answeredCount': currentAnswers.length,
        'eventType': eventType,
        'outOfAppSeconds': outOfAppSeconds,
        'detail': detail,
      });
    } catch (_) {}

    return updated;
  }

  /// Học sinh nộp bài thi có giám sát
  Future<ExamLiveSessionModel> submitSupervisedExam({
    required SupervisedExamModel exam,
    required ExamLiveSessionModel currentSession,
    required Map<String, int> answers,
  }) async {
    ExamLockGuard.instance.exitSupervisedExam();

    final isLate = DateTime.now().isAfter(exam.deadlineAt);
    final status = isLate ? 'submitted_late' : 'submitted_on_time';
    final score = _computeExamScore(exam.questions, answers);

    final updated = ExamLiveSessionModel(
      id: currentSession.id,
      examId: exam.id,
      userId: currentSession.userId,
      studentName: currentSession.studentName,
      studentEmail: currentSession.studentEmail,
      status: status,
      violationCount: currentSession.violationCount,
      violationLogs: currentSession.violationLogs,
      teacherWarningMessage: currentSession.teacherWarningMessage,
      answeredCount: answers.length,
      totalQuestions: exam.questions.length,
      currentAnswers: answers,
      score: score,
      startedAt: currentSession.startedAt,
      submittedAt: DateTime.now(),
      lastHeartbeatAt: DateTime.now(),
    );

    await _saveLiveSession(updated);

    try {
      final client = await _client();
      await client.postJson('/exams/supervised/${exam.id}/submit', {
        'sessionId': currentSession.id,
        'answers': answers,
      });
    } catch (_) {}

    return updated;
  }

  /// Giáo viên can thiệp trực tiếp trên Bảng Giám sát Phòng thi (Nhắc nhở / Thu bài ngay / Hủy kết quả / Cho làm tiếp)
  Future<ExamLiveSessionModel> performTeacherProctorAction({
    required SupervisedExamModel exam,
    required ExamLiveSessionModel session,
    required String
    action, // 'warn' | 'force_submit' | 'invalidate' | 'reset_violation'
    String? customMessage,
  }) async {
    String newStatus = session.status;
    int newViolations = session.violationCount;
    double newScore = session.score;
    String? warnMsg = customMessage;
    DateTime? submittedAt = session.submittedAt;

    if (action == 'warn') {
      warnMsg =
          customMessage ??
          '⚠️ Giáo viên nhắc nhở: Đề nghị ${session.studentName} tập trung làm bài nghiêm túc, không chuyển ứng dụng!';
    } else if (action == 'force_submit') {
      newStatus = 'force_submitted_teacher';
      newScore = _computeExamScore(exam.questions, session.currentAnswers);
      warnMsg =
          customMessage ??
          'Giáo viên đã chủ động thu bài thi của bạn ngay lập tức.';
      submittedAt = DateTime.now();
    } else if (action == 'invalidate') {
      newStatus = 'invalidated';
      newScore = 0.0;
      warnMsg =
          customMessage ??
          'Kết quả bài thi bị hủy (0 điểm) do vi phạm quy chế phòng thi.';
      submittedAt = DateTime.now();
    } else if (action == 'reset_violation') {
      newStatus = 'in_progress';
      newViolations = 0;
      warnMsg =
          'Giáo viên đã xác nhận sự cố kỹ thuật và cho phép bạn tiếp tục làm bài.';
      submittedAt = null;
    }

    final updated = ExamLiveSessionModel(
      id: session.id,
      examId: session.examId,
      userId: session.userId,
      studentName: session.studentName,
      studentEmail: session.studentEmail,
      status: newStatus,
      violationCount: newViolations,
      violationLogs: session.violationLogs,
      teacherWarningMessage: warnMsg,
      answeredCount: session.answeredCount,
      totalQuestions: session.totalQuestions,
      currentAnswers: session.currentAnswers,
      score: newScore,
      startedAt: session.startedAt,
      submittedAt: submittedAt,
      lastHeartbeatAt: DateTime.now(),
    );

    await _saveLiveSession(updated);

    await recordAuditLog(
      action: 'TEACHER_PROCTOR_${action.toUpperCase()}',
      targetType: 'exam_live_session',
      targetId: session.id,
      details:
          'Giáo viên thực hiện "$action" đối với học sinh ${session.studentName}',
    );

    try {
      final client = await _client();
      await client.postJson(
        '/teacher/exams/${exam.id}/sessions/${session.id}/action',
        {'action': action, 'message': warnMsg, 'reason': warnMsg},
      );
    } catch (_) {}

    return updated;
  }

  double _computeExamScore(
    List<Map<String, dynamic>> questions,
    Map<String, int> answers,
  ) {
    if (questions.isEmpty) return 0.0;
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qId = (q['id'] ?? '$i').toString();
      final chosen = answers[qId] ?? answers['$i'] ?? -1;
      final correctIdx = (q['correctIndex'] as num?)?.toInt() ?? 0;
      if (chosen == correctIdx) {
        correct += 1;
      }
    }
    return double.parse(((correct / questions.length) * 10).toStringAsFixed(2));
  }

  // ===========================================================================
  // 5. ADMIN: QUẢN LÝ NGƯỜI DÙNG, KHÓA TÀI KHOẢN & PHÂN QUYỀN (USERS CRUD & RBAC)
  // ===========================================================================
  Future<Map<String, dynamic>> _getLockedAccountsMap() async {
    final raw = await _repo.getSetting('admin_locked_accounts_map_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return {};
  }

  Future<void> _applyLockedAccountsOverride(
    List<Map<String, dynamic>> users,
  ) async {
    final lockedMap = await _getLockedAccountsMap();
    if (lockedMap.isEmpty) return;

    for (var i = 0; i < users.length; i++) {
      final em = (users[i]['email'] ?? '').toString().trim().toLowerCase();
      final id = (users[i]['id'] ?? '').toString();
      final key = lockedMap.containsKey(em)
          ? em
          : (lockedMap.containsKey(id) ? id : null);
      if (key != null) {
        final info = lockedMap[key];
        if (info is Map) {
          final isLocked = info['isLocked'] == true;
          users[i]['is_locked'] = isLocked;
          if (info['reason'] != null && info['reason'].toString().isNotEmpty) {
            users[i]['locked_reason'] = info['reason'].toString();
          }
        } else if (info == true) {
          users[i]['is_locked'] = true;
        }
      }
    }
  }

  Future<void> _recordLockedAccountState({
    required String userId,
    String? email,
    required bool isLocked,
    String? reason,
  }) async {
    final lockedMap = await _getLockedAccountsMap();
    final cleanEmail = email?.trim().toLowerCase();

    if (isLocked) {
      final info = {'isLocked': true, 'reason': reason ?? ''};
      if (cleanEmail != null && cleanEmail.isNotEmpty) {
        lockedMap[cleanEmail] = info;
      }
      lockedMap[userId] = info;
    } else {
      if (cleanEmail != null && cleanEmail.isNotEmpty) {
        lockedMap.remove(cleanEmail);
      }
      lockedMap.remove(userId);
    }
    await _repo.setSetting(
      'admin_locked_accounts_map_json',
      jsonEncode(lockedMap),
    );
    unawaited(syncLockedAccountsToCloud());
  }

  /// Đồng bộ danh sách tài khoản bị khóa từ local Admin lên Cloud PostgreSQL Render
  Future<Map<String, dynamic>> syncLockedAccountsToCloud() async {
    final lockedMap = await _getLockedAccountsMap();
    if (lockedMap.isEmpty) return {'syncedCount': 0};
    try {
      final list = <Map<String, String>>[];
      lockedMap.forEach((key, val) {
        if (key.contains('@') && val is Map && val['isLocked'] == true) {
          list.add({
            'email': key.trim().toLowerCase(),
            'reason': (val['reason'] ?? 'Tạm khóa bởi Quản trị viên')
                .toString(),
          });
        }
      });
      if (list.isEmpty) return {'syncedCount': 0};

      final client = await _client();
      final res = await client.postJson('/admin/users/sync-locked', {
        'lockedAccounts': list,
      });
      if (res.isSuccess && res.data != null) {
        return res.data!;
      }
    } catch (_) {}
    return {'syncedCount': 0};
  }

  Future<List<Map<String, dynamic>>> getAdminUsers({
    String? roleFilter,
    String? search,
  }) async {
    try {
      final client = await _client();
      final queryParams = <String>[];
      if (roleFilter != null && roleFilter != 'all')
        queryParams.add('role=$roleFilter');
      if (search != null && search.trim().isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(search.trim())}');
      }
      final qStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final res = await client.getJson(
        '/admin/users$qStr',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data?['users'] is List) {
        final serverUsers = (res.data!['users'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await _applyLockedAccountsOverride(serverUsers);
        await _repo.setSetting(
          'admin_cached_users_json',
          jsonEncode(serverUsers),
        );
        return serverUsers;
      }
    } catch (_) {}

    final raw = await _repo.getSetting('admin_cached_users_json');
    List<Map<String, dynamic>> users = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        users = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }

    await _applyLockedAccountsOverride(users);

    // Luôn đảm bảo tài khoản quản trị hệ thống tongan542@gmail.com mang vai trò admin
    for (var i = 0; i < users.length; i++) {
      final uEmail = (users[i]['email'] ?? '').toString().trim().toLowerCase();
      if (UserProfile.isSystemAdmin(uEmail)) {
        users[i]['role'] = 'admin';
      }
    }

    // Xóa sạch toàn bộ tài khoản mock/test ảo cũ nếu còn tồn lưu trong bộ nhớ cache
    final origLen = users.length;
    users.removeWhere((u) {
      final em = (u['email'] ?? '').toString().trim().toLowerCase();
      final id = (u['id'] ?? '').toString().trim().toLowerCase();
      final name = (u['display_name'] ?? u['displayName'] ?? '')
          .toString()
          .toLowerCase();
      if (UserProfile.isSystemAdmin(em))
        return false; // Không bao giờ xóa admin hệ thống
      return id.contains('mock') ||
          id.contains('fake') ||
          id.contains('teacher_pending') ||
          em.contains('mock') ||
          em.contains('fake') ||
          em.contains('example.com') ||
          name.contains('mẫu') ||
          name.contains('mock');
    });
    if (users.length != origLen) {
      await _repo.setSetting('admin_cached_users_json', jsonEncode(users));
    }

    if (users.isEmpty) {
      final currentAuth = await _repo.getAuthUser();
      users = [
        {
          'id': 'usr_admin_tongan',
          'email': UserProfile.systemAdminEmail,
          'display_name': 'anbao (Quản trị viên)',
          'role': 'admin',
          'is_locked': false,
          'locked_reason': '',
          'created_at': DateTime.now().toIso8601String(),
        },
        if (currentAuth != null &&
            !UserProfile.isSystemAdmin(currentAuth.email))
          {
            'id': currentAuth.id,
            'email': currentAuth.email,
            'display_name': currentAuth.displayName,
            'role': currentAuth.role,
            'is_locked': currentAuth.isLocked,
            'locked_reason': currentAuth.lockedReason,
            'created_at': DateTime.now().toIso8601String(),
          },
      ];
      await _repo.setSetting('admin_cached_users_json', jsonEncode(users));
    }

    return users.where((u) {
      if (roleFilter != null &&
          roleFilter != 'all' &&
          u['role'] != roleFilter) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final name = (u['display_name'] ?? u['displayName'] ?? '')
            .toString()
            .toLowerCase();
        if (!email.contains(s) && !name.contains(s)) return false;
      }
      return true;
    }).toList();
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final newUser = {
      'id': 'usr_${DateTime.now().millisecondsSinceEpoch}',
      'email': email.trim().toLowerCase(),
      'display_name': displayName.trim().isEmpty
          ? email.split('@').first
          : displayName.trim(),
      'role': role,
      'is_locked': false,
      'locked_reason': '',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final client = await _client();
      final res = await client.postJson('/admin/users', {
        'email': email.trim(),
        'password': password,
        'displayName': displayName.trim(),
        'role': role,
      });
      if (res.isSuccess && res.data?['user'] is Map) {
        final created = Map<String, dynamic>.from(res.data!['user'] as Map);
        await _upsertLocalAdminUser(created);
        return created;
      }
    } catch (_) {}

    await _upsertLocalAdminUser(newUser);
    await recordAuditLog(
      action: 'ADMIN_CREATE_USER',
      targetType: 'user',
      targetId: newUser['id'].toString(),
      details:
          'Tạo tài khoản ${newUser['email']} với vai trò ${role.toUpperCase()}',
    );
    return newUser;
  }

  Future<bool> updateAdminUser({
    required String userId,
    String? email,
    String? displayName,
    String? role,
    bool? isLocked,
    String? lockedReason,
  }) async {
    lastAdminUserError = null;
    final list = await getAdminUsers();
    final cleanEmail = email?.trim().toLowerCase();
    int idx = list.indexWhere((u) => u['id']?.toString() == userId);
    if (idx < 0 && cleanEmail != null && cleanEmail.isNotEmpty) {
      idx = list.indexWhere(
        (u) => u['email']?.toString().trim().toLowerCase() == cleanEmail,
      );
    }

    bool serverSuccess = false;
    try {
      final client = await _client();
      final payload = <String, dynamic>{};
      if (displayName != null) payload['displayName'] = displayName;
      if (role != null) payload['role'] = role;
      if (isLocked != null) payload['isLocked'] = isLocked;
      if (lockedReason != null) payload['lockedReason'] = lockedReason;
      if (cleanEmail != null && cleanEmail.isNotEmpty)
        payload['email'] = cleanEmail;

      final res = await client.putJson('/admin/users/$userId', payload);
      if (res.isSuccess) {
        serverSuccess = true;
        if (res.data?['user'] is Map) {
          final serverUser = Map<String, dynamic>.from(
            res.data!['user'] as Map,
          );
          if (idx >= 0) {
            list[idx] = serverUser;
          } else {
            list.add(serverUser);
          }
          await _repo.setSetting('admin_cached_users_json', jsonEncode(list));
        }
      } else {
        lastAdminUserError = res.errorMessage ?? 'Máy chủ từ chối cập nhật tài khoản.';
      }
    } catch (error) {
      lastAdminUserError = 'Không thể kết nối máy chủ: $error';
    }

    if (!serverSuccess) {
      return false;
    }

    if (idx >= 0) {
      final cur = Map<String, dynamic>.from(list[idx]);
      if (displayName != null) cur['display_name'] = displayName;
      if (role != null) cur['role'] = role;
      if (isLocked != null) cur['is_locked'] = isLocked;
      if (lockedReason != null) cur['locked_reason'] = lockedReason;
      list[idx] = cur;
      await _repo.setSetting('admin_cached_users_json', jsonEncode(list));
    }

    if (isLocked != null) {
      await _recordLockedAccountState(
        userId: userId,
        email: cleanEmail,
        isLocked: isLocked,
        reason: lockedReason,
      );
    }

    await recordAuditLog(
      action: isLocked != null
          ? (isLocked ? 'LOCK_USER_ACCOUNT' : 'UNLOCK_USER_ACCOUNT')
          : 'UPDATE_USER_ROLE',
      targetType: 'user',
      targetId: userId,
      details:
          'Cập nhật người dùng $userId (${cleanEmail ?? ''}) (Role: ${role ?? "giữ nguyên"}, Khóa: ${isLocked ?? false})',
    );

    return serverSuccess;
  }

  Future<void> deleteAdminUser(String userId) async {
    final list = await getAdminUsers();
    list.removeWhere((u) => u['id'] == userId);
    await _repo.setSetting('admin_cached_users_json', jsonEncode(list));

    await recordAuditLog(
      action: 'ADMIN_DELETE_USER',
      targetType: 'user',
      targetId: userId,
      details: 'Xóa tài khoản người dùng $userId',
    );

    try {
      final client = await _client();
      await client.deleteJson('/admin/users/$userId');
    } catch (_) {}
  }

  Future<void> _upsertLocalAdminUser(Map<String, dynamic> user) async {
    final list = await getAdminUsers();
    final idx = list.indexWhere(
      (u) => u['id'] == user['id'] || u['email'] == user['email'],
    );
    if (idx >= 0) {
      list[idx] = user;
    } else {
      list.insert(0, user);
    }
    await _repo.setSetting('admin_cached_users_json', jsonEncode(list));
  }

  // ===========================================================================
  // 6. ADMIN: QUẢN LÝ & THAY THẾ BỘ DỮ LIỆU SÁCH GIÁO KHOA MỚI (CURRICULUM VERSIONING)
  // ===========================================================================
  Future<List<Map<String, dynamic>>> getCurriculumVersions() async {
    final raw = await _repo.getSetting('curriculum_versions_json');
    List<Map<String, dynamic>> versions = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        versions = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }

    if (versions.isEmpty) {
      versions = [
        {
          'id': 'cur_gs12_2025_standard',
          'versionCode': 'GS12-2025.1',
          'title': 'SGK Tiếng Anh 12 Global Success (Bộ chuẩn hiện hành)',
          'description':
              'Đầy đủ 10 Unit chuẩn Bộ GD&ĐT (Life Stories, Multicultural World, Green Living, Urbanisation, World of Work, AI...).',
          'isActive': true,
          'unitCount': 10,
          'updatedAt': DateTime.now().toIso8601String(),
          'payload': <String, dynamic>{},
        },
      ];
      await _repo.setSetting('curriculum_versions_json', jsonEncode(versions));
    }
    return versions;
  }

  /// Tạo hoặc cập nhật phiên bản Bộ sách giáo khoa mới, hỗ trợ kích hoạt thay thế ngay lập tức
  Future<Map<String, dynamic>> saveAndOptionallyActivateCurriculum({
    String? id,
    required String versionCode,
    required String title,
    required String description,
    required Map<String, dynamic> payload,
    bool activateImmediately = false,
  }) async {
    final versions = await getCurriculumVersions();
    final curId = id ?? 'cur_${DateTime.now().millisecondsSinceEpoch}';

    if (activateImmediately) {
      for (final v in versions) {
        v['isActive'] = false;
      }
    }

    final item = {
      'id': curId,
      'versionCode': versionCode.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'isActive': activateImmediately,
      'unitCount': (payload['units'] as List?)?.length ?? 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'payload': payload,
    };

    final idx = versions.indexWhere((v) => v['id'] == curId);
    if (idx >= 0) {
      versions[idx] = item;
    } else {
      versions.insert(0, item);
    }

    await _repo.setSetting('curriculum_versions_json', jsonEncode(versions));

    if (activateImmediately) {
      await _applyCurriculumPayloadToLocalSqlite(payload);
    }

    await recordAuditLog(
      action: activateImmediately
          ? 'ACTIVATE_NEW_TEXTBOOK'
          : 'SAVE_CURRICULUM_VERSION',
      targetType: 'curriculum_set',
      targetId: curId,
      details:
          '${activateImmediately ? "Thay thế & Kích hoạt" : "Lưu"} bộ sách "$title" ($versionCode)',
    );

    try {
      final client = await _client();
      await client.postJson('/admin/curriculums', {
        'versionCode': versionCode,
        'title': title,
        'description': description,
        'payload': payload,
        'activateImmediately': activateImmediately,
      });
    } catch (_) {}

    return item;
  }

  Future<void> activateCurriculumVersion(String curriculumId) async {
    final versions = await getCurriculumVersions();
    Map<String, dynamic>? target;
    for (final v in versions) {
      if (v['id'] == curriculumId) {
        v['isActive'] = true;
        target = v;
      } else {
        v['isActive'] = false;
      }
    }
    await _repo.setSetting('curriculum_versions_json', jsonEncode(versions));

    if (target != null && target['payload'] is Map) {
      await _applyCurriculumPayloadToLocalSqlite(
        Map<String, dynamic>.from(target['payload'] as Map),
      );
    }

    await recordAuditLog(
      action: 'SWITCH_ACTIVE_CURRICULUM',
      targetType: 'curriculum_set',
      targetId: curriculumId,
      details:
          'Kích hoạt bộ sách giáo khoa "${target?['title'] ?? curriculumId}" cho toàn hệ thống',
    );

    try {
      final client = await _client();
      await client.postJson('/admin/curriculums/$curriculumId/activate', {});
    } catch (_) {}
  }

  Future<void> deleteCurriculumVersion(String curriculumId) async {
    final versions = await getCurriculumVersions();
    versions.removeWhere(
      (v) => v['id'] == curriculumId && v['isActive'] != true,
    );
    await _repo.setSetting('curriculum_versions_json', jsonEncode(versions));

    await recordAuditLog(
      action: 'DELETE_CURRICULUM_VERSION',
      targetType: 'curriculum_set',
      targetId: curriculumId,
      details: 'Xóa phiên bản bộ sách $curriculumId',
    );
  }

  /// Đồng bộ dữ liệu từ gói Sách Giáo Khoa Mới vào bảng `topics`, `words`, `questions` của SQLite
  /// mà KHÔNG làm mất dữ liệu `attempts`, `daily_stats`, `word_progress` của học viên!
  Future<void> _applyCurriculumPayloadToLocalSqlite(
    Map<String, dynamic> payload,
  ) async {
    if (payload.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();

    final units = payload['units'] is List
        ? (payload['units'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
        : (payload['unitNumber'] != null
              ? [payload]
              : <Map<String, dynamic>>[]);

    for (final u in units) {
      final unitNum = (u['unitNumber'] as num?)?.toInt() ?? 1;
      final topicId = 't$unitNum';
      final title = (u['title'] ?? 'Unit $unitNum').toString();

      batch.insert(
        'topics',
        Topic(
          id: topicId,
          grade: 12,
          title: title.startsWith('Unit') ? title : 'Unit $unitNum: $title',
          order: unitNum,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (u['vocabulary'] is List) {
        final vocabList = u['vocabulary'] as List;
        for (int i = 0; i < vocabList.length; i++) {
          final v = Map<String, dynamic>.from(vocabList[i] as Map);
          final eng = (v['english'] ?? '').toString().trim();
          if (eng.isEmpty) continue;
          batch.insert(
            'words',
            Word(
              id: 'w_u${unitNum}_${eng.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              topicId: topicId,
              grade: 12,
              english: eng,
              ipa: (v['ipa'] ?? '/$eng/').toString(),
              meaningVi: (v['meaningVi'] ?? '').toString(),
              example: (v['example'] ?? '').toString(),
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (u['questions'] is List) {
        final qList = u['questions'] as List;
        for (int i = 0; i < qList.length; i++) {
          final q = Map<String, dynamic>.from(qList[i] as Map);
          final stem = (q['stem'] ?? '').toString().trim();
          final opts =
              (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (stem.isEmpty || opts.length < 2) continue;
          batch.insert(
            'questions',
            Question(
              id:
                  (q['id'] ??
                          'q_u${unitNum}_${DateTime.now().millisecondsSinceEpoch}_$i')
                      .toString(),
              grade: 12,
              type: (q['skill'] ?? 'reading').toString(),
              stem: stem,
              options: opts,
              correctIndex: (q['correctIndex'] as num?)?.toInt() ?? 0,
              explanation: (q['explanation'] ?? '').toString(),
              topicId: topicId,
              difficulty: (q['difficulty'] as num?)?.toInt() ?? 2,
            ).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }

    await batch.commit(noResult: true);
  }

  // ===========================================================================
  // 7. NHẬT KÝ GIÁM SÁT HỆ THỐNG (SYSTEM AUDIT LOGS)
  // ===========================================================================
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final raw = await _repo.getSetting('system_audit_logs_json');
    List<Map<String, dynamic>> logs = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        logs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return logs;
  }

  Future<void> recordAuditLog({
    required String action,
    required String targetType,
    required String targetId,
    required String details,
  }) async {
    final logs = await getAuditLogs();
    final user = await _repo.getAuthUser();
    logs.insert(0, {
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
      'actorEmail': user?.email.isNotEmpty == true
          ? user!.email
          : (user?.displayName ?? 'system'),
      'actorRole': user?.role ?? 'admin',
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (logs.length > 100) {
      logs.removeRange(100, logs.length);
    }
    await _repo.setSetting('system_audit_logs_json', jsonEncode(logs));
  }

  Future<void> clearAuditLogs() async {
    await _repo.setSetting('system_audit_logs_json', jsonEncode([]));
    await recordAuditLog(
      action: 'CLEAR_AUDIT_LOGS',
      targetType: 'system_log',
      targetId: 'all',
      details: 'Quản trị viên đã dọn dẹp và làm mới nhật ký kiểm toán hệ thống',
    );
  }

  // ===========================================================================
  // 8. GIẢI TRÌNH PHÒNG THI, QUẢN LÝ LỚP HỌC, BÀI GIAO, BÁO LỖI & THÔNG BÁO THẬT
  // ===========================================================================

  /// Học sinh gửi giải trình khi bài thi bị tự động nộp sau 10 giây rời app
  Future<ExamLiveSessionModel?> submitExamExplanation({
    required String examId,
    required String sessionId,
    required String explanation,
  }) async {
    final sessions = await getLiveSessionsForExam(examId);
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    ExamLiveSessionModel? updated;
    if (idx >= 0) {
      final cur = sessions[idx];
      updated = ExamLiveSessionModel(
        id: cur.id,
        examId: cur.examId,
        userId: cur.userId,
        studentName: cur.studentName,
        studentEmail: cur.studentEmail,
        status: cur.status,
        violationCount: cur.violationCount,
        violationLogs: cur.violationLogs,
        teacherWarningMessage: cur.teacherWarningMessage,
        studentExplanation: explanation.trim(),
        explanationSubmittedAt: DateTime.now(),
        answeredCount: cur.answeredCount,
        totalQuestions: cur.totalQuestions,
        currentAnswers: cur.currentAnswers,
        score: cur.score,
        startedAt: cur.startedAt,
        submittedAt: cur.submittedAt,
        lastHeartbeatAt: DateTime.now(),
      );
      await _saveLiveSession(updated);
    }

    await recordAuditLog(
      action: 'SUBMIT_EXAM_EXPLANATION',
      targetType: 'exam_live_session',
      targetId: sessionId,
      details: 'Học sinh gửi giải trình phòng thi: "${explanation.trim()}"',
    );

    try {
      final client = await _client();
      final res = await client.postJson('/exams/supervised/$examId/explain', {
        'sessionId': sessionId,
        'explanation': explanation.trim(),
      });
      if (res.isSuccess && res.data?['session'] is Map) {
        final serverUpdated = ExamLiveSessionModel.fromMap(
          Map<String, dynamic>.from(res.data!['session'] as Map),
        );
        await _saveLiveSession(serverUpdated);
        return serverUpdated;
      }
    } catch (_) {}

    return updated;
  }

  /// Lấy danh sách Lớp học thật (Đồng bộ SQLite & Backend, không có dữ liệu mẫu giả)
  Future<List<Map<String, dynamic>>> getClasses() async {
    final delRaw = await _repo.getSetting('deleted_class_ids_json');
    final Set<String> deletedIds = {};
    if (delRaw != null && delRaw.isNotEmpty) {
      try {
        deletedIds.addAll(
          (jsonDecode(delRaw) as List).map((e) => e.toString()),
        );
      } catch (_) {}
    }

    final raw = await _repo.getSetting('admin_classes_json');
    List<Map<String, dynamic>> localList = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        localList = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where(
              (c) =>
                  !deletedIds.contains(c['id'].toString()) &&
                  !deletedIds.contains((c['code'] ?? '').toString()),
            )
            .toList();
      } catch (_) {}
    }

    try {
      final client = await _client();
      final res = await client.getJson(
        '/classes',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data?['classes'] is List) {
        final serverList = (res.data!['classes'] as List)
            .map((e) => _normalizeClassMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (serverList.isNotEmpty) {
          for (final sc in serverList) {
            final scId = sc['id'].toString();
            final scCode = (sc['code'] ?? '').toString();
            // Nếu lớp học đã bị xóa, tuyệt đối không phục hồi/thêm lại vào danh sách
            if (deletedIds.contains(scId) || deletedIds.contains(scCode)) {
              continue;
            }
            final idx = localList.indexWhere((l) => l['id'] == sc['id']);
            if (idx >= 0) {
              localList[idx] = sc;
            } else {
              localList.add(sc);
            }
          }
          await _repo.setSetting('admin_classes_json', jsonEncode(localList));
        }
      }
    } catch (_) {}

    // Cập nhật số lượng học sinh & bài đang mở thực tế từ bảng members và assignments
    final allAssignments = await _getAssignmentsRaw();
    for (int i = 0; i < localList.length; i++) {
      final c = Map<String, dynamic>.from(localList[i]);
      final cid = (c['id'] ?? '').toString();
      final members = await getClassMembers(cid, syncRemote: false);
      final approvedCount = members
          .where((m) => m['status'] == 'approved')
          .length;
      final pendingCount = members
          .where((m) => m['status'] == 'pending')
          .length;
      final openAssignCount = allAssignments
          .where((a) => a['classId'] == cid && a['status'] != 'closed')
          .length;
      c['studentsCount'] = approvedCount > 0
          ? approvedCount
          : ((c['studentsCount'] as num?)?.toInt() ?? 0);
      c['pendingCount'] = pendingCount;
      c['openAssignmentsCount'] = openAssignCount;
      localList[i] = c;
    }

    return localList;
  }

  Map<String, dynamic> _normalizeClassMap(Map<String, dynamic> m) {
    return {
      'id': (m['id'] ?? '').toString(),
      'name': (m['name'] ?? '').toString(),
      'schoolName': (m['schoolName'] ?? m['school_name'] ?? 'THPT').toString(),
      'schoolYear': (m['schoolYear'] ?? m['school_year'] ?? '2026-2027')
          .toString(),
      'bookSet':
          (m['bookSet'] ?? m['book_set'] ?? 'SGK Tiếng Anh 12 Global Success')
              .toString(),
      'teacherId': (m['teacherId'] ?? m['teacher_id'] ?? '').toString(),
      'teacherName': (m['teacherName'] ?? m['teacher_name'] ?? '').toString(),
      'teacherEmail': (m['teacherEmail'] ?? m['teacher_email'] ?? '')
          .toString(),
      'code': (m['code'] ?? m['join_code'] ?? '').toString(),
      'requireApproval':
          m['requireApproval'] == true || m['require_approval'] == true,
      'showLeaderboard':
          m['showLeaderboard'] != false && m['show_leaderboard'] != false,
      'allowJoin': m['allowJoin'] != false && m['allow_join'] != false,
      'membershipStatus':
          (m['membershipStatus'] ?? m['membership_status'] ?? '').toString(),
      'status': (m['status'] ?? 'active').toString(),
      'studentsCount': (m['studentsCount'] ?? m['student_count'] ?? 0 as num)
          .toInt(),
      'pendingCount': (m['pendingCount'] ?? m['pending_count'] ?? 0 as num)
          .toInt(),
      'progressPercent':
          (m['progressPercent'] ?? m['progress_percent'] ?? 0 as num).toInt(),
      'createdAt':
          (m['createdAt'] ??
                  m['created_at'] ??
                  DateTime.now().toIso8601String())
              .toString(),
    };
  }

  static String generateClassJoinCode(String className) {
    const vietnameseMap = {
      'a': 'a',
      'á': 'a',
      'à': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ắ': 'a',
      'ằ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ấ': 'a',
      'ầ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'd': 'd',
      'đ': 'd',
      'e': 'e',
      'é': 'e',
      'è': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ế': 'e',
      'ề': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'i': 'i',
      'í': 'i',
      'ì': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'o': 'o',
      'ó': 'o',
      'ò': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ố': 'o',
      'ồ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ớ': 'o',
      'ờ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'u': 'u',
      'ú': 'u',
      'ù': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ứ': 'u',
      'ừ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'y': 'y',
      'ý': 'y',
      'ỳ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
    };
    var normalized = className.toLowerCase();
    vietnameseMap.forEach(
      (key, val) => normalized = normalized.replaceAll(key, val),
    );
    final clean = normalized.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final prefix = clean.padRight(4, 'X').substring(0, 4);
    final rand = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000))
        .toString();
    return '$prefix-$rand';
  }

  Future<Map<String, dynamic>> createClass({
    required String name,
    String schoolName = 'THPT',
    String schoolYear = '2026-2027',
    String bookSet = 'SGK Tiếng Anh 12 Global Success',
    String? joinCode,
    bool requireApproval = true,
    bool showLeaderboard = true,
    String? teacherId,
    String? teacherName,
    String? teacherEmail,
  }) async {
    final user = await _repo.getAuthUser();
    final classes = await getClasses();
    final code = (joinCode != null && joinCode.trim().isNotEmpty)
        ? joinCode.trim().toUpperCase()
        : generateClassJoinCode(name);

    final newClass = {
      'id': 'cls_${DateTime.now().millisecondsSinceEpoch}',
      'name': name.trim(),
      'schoolName': schoolName.trim(),
      'schoolYear': schoolYear.trim(),
      'bookSet': bookSet.trim(),
      'teacherId': teacherId ?? user?.id ?? '',
      'teacherName': teacherName ?? user?.displayName ?? 'Giáo viên',
      'teacherEmail': teacherEmail ?? user?.email ?? '',
      'code': code,
      'requireApproval': requireApproval,
      'showLeaderboard': showLeaderboard,
      'allowJoin': true,
      'status': 'active',
      'studentsCount': 0,
      'pendingCount': 0,
      'progressPercent': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    classes.insert(0, newClass);
    await _repo.setSetting('admin_classes_json', jsonEncode(classes));

    await recordAuditLog(
      action: 'CREATE_CLASS',
      targetType: 'class',
      targetId: newClass['id'].toString(),
      details: 'Tạo lớp học "${newClass['name']}" (Mã lớp: $code)',
    );

    try {
      final client = await _client();
      final res = await client.postJson('/classes', {
        'id': newClass['id'],
        'name': name.trim(),
        'schoolName': schoolName.trim(),
        'schoolYear': schoolYear.trim(),
        'bookSet': bookSet.trim(),
        'joinCode': code,
        'requireApproval': requireApproval,
        'showLeaderboard': showLeaderboard,
        'teacherName': newClass['teacherName'],
        'teacherEmail': newClass['teacherEmail'],
      });
      if (res.isSuccess &&
          (res.data?['classItem'] is Map || res.data?['class'] is Map)) {
        final rawServer = (res.data?['classItem'] ?? res.data?['class']) as Map;
        final serverClass = _normalizeClassMap(
          Map<String, dynamic>.from(rawServer),
        );
        classes[0] = serverClass;
        await _repo.setSetting('admin_classes_json', jsonEncode(classes));
        unawaited(syncAllClassesToCloud());
        return serverClass;
      }
    } catch (_) {}

    unawaited(syncAllClassesToCloud());
    return newClass;
  }

  /// Đồng bộ toàn bộ các lớp học từ máy Giáo viên/Admin lên Cloud PostgreSQL (Render)
  Future<Map<String, dynamic>> syncAllClassesToCloud() async {
    final classes = await getClasses();
    if (classes.isEmpty) {
      return {
        'ok': true,
        'count': 0,
        'message': 'Không có lớp học nào để đồng bộ.',
      };
    }
    try {
      final client = await _client();
      final res = await client.postJson('/classes/batch-sync', {
        'classes': classes,
      });
      if (res.isSuccess && res.data != null) {
        final count =
            (res.data!['syncedCount'] as num?)?.toInt() ?? classes.length;
        return {
          'ok': true,
          'count': count,
          'message':
              res.data!['message'] ??
              'Đã đồng bộ $count lớp học lên Cloud thành công!',
        };
      }
      return {
        'ok': false,
        'count': 0,
        'message':
            res.data?['error']?.toString() ?? 'Máy chủ Cloud từ chối đồng bộ.',
      };
    } catch (e) {
      return {
        'ok': false,
        'count': 0,
        'message': 'Lỗi kết nối máy chủ Cloud: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> updateClass({
    required String classId,
    String? name,
    String? schoolName,
    String? teacherId,
    String? teacherName,
    String? teacherEmail,
    String? joinCode,
    bool? requireApproval,
    bool? showLeaderboard,
    bool? allowJoin,
    String? status,
  }) async {
    final classes = await getClasses();
    final idx = classes.indexWhere((c) => c['id'] == classId);
    if (idx < 0) return null;

    final cur = Map<String, dynamic>.from(classes[idx]);
    if (name != null) cur['name'] = name.trim();
    if (schoolName != null) cur['schoolName'] = schoolName.trim();
    if (teacherId != null) cur['teacherId'] = teacherId.trim();
    if (teacherName != null) cur['teacherName'] = teacherName.trim();
    if (teacherEmail != null) cur['teacherEmail'] = teacherEmail.trim();
    if (joinCode != null) cur['code'] = joinCode.trim().toUpperCase();
    if (requireApproval != null) cur['requireApproval'] = requireApproval;
    if (showLeaderboard != null) cur['showLeaderboard'] = showLeaderboard;
    if (allowJoin != null) cur['allowJoin'] = allowJoin;
    if (status != null) cur['status'] = status;

    classes[idx] = cur;
    await _repo.setSetting('admin_classes_json', jsonEncode(classes));

    await recordAuditLog(
      action: 'UPDATE_CLASS',
      targetType: 'class',
      targetId: classId,
      details:
          'Cập nhật lớp học "${cur['name']}" (Mã: ${cur['code']}, Trạng thái: ${cur['status']})',
    );

    try {
      final client = await _client();
      await client.putJson('/classes/$classId', {
        'name': cur['name'],
        'schoolName': cur['schoolName'],
        'teacherId': cur['teacherId'],
        'teacherName': cur['teacherName'],
        'teacherEmail': cur['teacherEmail'],
        'joinCode': cur['code'],
        'requireApproval': cur['requireApproval'],
        'showLeaderboard': cur['showLeaderboard'],
        'allowJoin': cur['allowJoin'],
        'status': cur['status'],
      });
    } catch (_) {}

    unawaited(syncAllClassesToCloud());
    return cur;
  }

  Future<String> regenerateClassCode(String classId) async {
    final classes = await getClasses();
    final idx = classes.indexWhere((c) => c['id'] == classId);
    final className = idx >= 0
        ? (classes[idx]['name'] ?? 'CLASS').toString()
        : 'CLASS';
    final newCode = generateClassJoinCode(className);
    await updateClass(classId: classId, joinCode: newCode);
    return newCode;
  }

  /// Xóa hoặc Giải tán một lớp học khỏi hệ thống
  Future<bool> deleteClass(String classId) async {
    final classes = await getClasses();
    final idx = classes.indexWhere(
      (c) =>
          c['id'].toString() == classId.toString() ||
          (c['code'] ?? '').toString() == classId.toString(),
    );

    // Lưu ID và mã lớp vào danh sách đã xóa vĩnh viễn để chống auto-fetch hồi sinh
    final delRaw = await _repo.getSetting('deleted_class_ids_json');
    final Set<String> deletedIds = {};
    if (delRaw != null && delRaw.isNotEmpty) {
      try {
        deletedIds.addAll(
          (jsonDecode(delRaw) as List).map((e) => e.toString()),
        );
      } catch (_) {}
    }
    deletedIds.add(classId.toString());

    if (idx >= 0) {
      final removed = classes.removeAt(idx);
      if (removed['id'] != null) deletedIds.add(removed['id'].toString());
      if (removed['code'] != null) deletedIds.add(removed['code'].toString());
      await _repo.setSetting('admin_classes_json', jsonEncode(classes));
      await _repo.setSetting('class_members_$classId', '[]');

      await recordAuditLog(
        action: 'DELETE_CLASS',
        targetType: 'class',
        targetId: classId,
        details:
            'Giải tán / Xóa lớp học "${removed['name']}" (Mã: ${removed['code']})',
      );
    }
    await _repo.setSetting(
      'deleted_class_ids_json',
      jsonEncode(deletedIds.toList()),
    );

    // Xóa khỏi danh sách lớp đã tham gia của học sinh
    final joinedRaw = await _repo.getSetting('student_joined_classes_json');
    if (joinedRaw != null && joinedRaw.isNotEmpty) {
      try {
        final jList = (jsonDecode(joinedRaw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        jList.removeWhere(
          (c) =>
              c['id'].toString() == classId.toString() ||
              (c['code'] ?? '').toString() == classId.toString(),
        );
        await _repo.setSetting(
          'student_joined_classes_json',
          jsonEncode(jList),
        );
      } catch (_) {}
    }

    try {
      final client = await _client();
      await client.deleteJson('/classes/$classId');
    } catch (_) {}

    return true;
  }

  /// Lấy danh sách các lớp học mà học sinh hiện tại đang tham gia
  Future<List<Map<String, dynamic>>> getMyJoinedClasses() async {
    final user = await _repo.getAuthUser();
    final studentId = user?.id ?? '';
    final studentEmail = (user?.email ?? '').trim().toLowerCase();

    final delRaw = await _repo.getSetting('deleted_class_ids_json');
    final Set<String> deletedIds = {};
    if (delRaw != null && delRaw.isNotEmpty) {
      try {
        deletedIds.addAll(
          (jsonDecode(delRaw) as List).map((e) => e.toString()),
        );
      } catch (_) {}
    }

    // 1. Thử gọi API lấy lớp học từ server Neon
    try {
      final client = await _client();
      final res = await client.getJson(
        '/classes',
        timeout: const Duration(seconds: 6),
      );
      if (res.isSuccess && res.data?['classes'] is List) {
        final serverList = (res.data!['classes'] as List)
            .map((e) => _normalizeClassMap(Map<String, dynamic>.from(e as Map)))
            .where(
              (c) =>
                  !deletedIds.contains(c['id'].toString()) &&
                  !deletedIds.contains((c['code'] ?? '').toString()),
            )
            .toList();
        if (serverList.isNotEmpty) {
          await _repo.setSetting(
            'student_joined_classes_json',
            jsonEncode(serverList),
          );
          return serverList;
        }
      }
    } catch (_) {}

    // 2. Đọc từ cache đã lưu
    final cached = await _repo.getSetting('student_joined_classes_json');
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where(
              (c) =>
                  !deletedIds.contains(c['id'].toString()) &&
                  !deletedIds.contains((c['code'] ?? '').toString()),
            )
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // 3. Quét kiểm tra trong toàn bộ lớp học cục bộ
    final allClasses = await getClasses();
    final joined = <Map<String, dynamic>>[];
    for (final c in allClasses) {
      final cid = c['id'].toString();
      final cCode = (c['code'] ?? '').toString();
      if (deletedIds.contains(cid) || deletedIds.contains(cCode)) continue;
      final members = await getClassMembers(cid, syncRemote: false);
      final matchedMember = members.where((m) {
        final mId = (m['studentId'] ?? '').toString();
        final mEmail = (m['studentEmail'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return (studentId.isNotEmpty && mId == studentId) ||
            (studentEmail.isNotEmpty && mEmail == studentEmail);
      }).firstOrNull;

      if (matchedMember != null) {
        final copy = Map<String, dynamic>.from(c);
        copy['membershipStatus'] = matchedMember['status'] ?? 'approved';
        joined.add(copy);
      }
    }
    return joined;
  }

  /// Học sinh nhập Mã lớp để tham gia lớp học
  Future<Map<String, dynamic>> joinClassByCode(String joinCode) async {
    final cleanCode = joinCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'ok': false, 'message': 'Vui lòng nhập mã lớp học.'};
    }

    final user = await _repo.getAuthUser();
    final studentId = user?.id ?? 'usr_student_local';
    final studentName = (user?.displayName.isNotEmpty == true)
        ? user!.displayName
        : 'Học sinh';
    final studentEmail = user?.email ?? '';

    // 1. Gửi request tham gia lớp học lên Cloud Backend Render
    try {
      final client = await _client();
      final res = await client.postJson('/classes/join', {
        'joinCode': cleanCode,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
      });
      if (res.isSuccess && res.data != null) {
        final rawStatus =
            res.data!['membership']?['status'] ??
            res.data!['memberStatus'] ??
            'approved';
        final status = (rawStatus == 'active') ? 'approved' : rawStatus;
        final classData = res.data!['classItem'] ?? res.data!['class'];
        final classMap = classData is Map
            ? _normalizeClassMap(Map<String, dynamic>.from(classData))
            : null;
        if (classMap != null) {
          classMap['membershipStatus'] = status;
          final myJoined = await getMyJoinedClasses();
          final jIdx = myJoined.indexWhere((c) => c['id'] == classMap['id']);
          if (jIdx >= 0) {
            myJoined[jIdx] = classMap;
          } else {
            myJoined.insert(0, classMap);
          }
          await _repo.setSetting(
            'student_joined_classes_json',
            jsonEncode(myJoined),
          );
        }
        return {
          'ok': true,
          'status': status,
          'message': res.data!['message'] ?? 'Tham gia lớp học thành công.',
          'classItem': classMap,
        };
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return {
          'ok': false,
          'message':
              res.errorMessage ??
              'Phiên đăng nhập không hợp lệ hoặc tài khoản không được phép tham gia lớp.',
        };
      }

      // 2. Nếu join trực tiếp chưa nhận diện, thử tra cứu lớp công khai trên Cloud Render
      final lookupRes = await client.getJson('/classes/lookup/$cleanCode');
      if (lookupRes.isSuccess && lookupRes.data?['classItem'] is Map) {
        final rawLookup = lookupRes.data!['classItem'] as Map;
        final cloudClass = _normalizeClassMap(
          Map<String, dynamic>.from(rawLookup),
        );
        if (cloudClass['allowJoin'] == false ||
            cloudClass['status'] == 'archived') {
          return {
            'ok': false,
            'message': 'Lớp học này hiện đã đóng nhận học sinh mới.',
          };
        }
        final status = cloudClass['requireApproval'] == true
            ? 'pending'
            : 'approved';
        cloudClass['membershipStatus'] = status;

        final myJoined = await getMyJoinedClasses();
        final jIdx = myJoined.indexWhere((c) => c['id'] == cloudClass['id']);
        if (jIdx >= 0) {
          myJoined[jIdx] = cloudClass;
        } else {
          myJoined.insert(0, cloudClass);
        }
        await _repo.setSetting(
          'student_joined_classes_json',
          jsonEncode(myJoined),
        );

        await recordAuditLog(
          action: 'STUDENT_JOIN_CLASS_CLOUD',
          targetType: 'class',
          targetId: cloudClass['id'].toString(),
          details:
              '$studentName tham gia lớp ${cloudClass['name']} từ Cloud Render qua mã $cleanCode ($status)',
        );

        return {
          'ok': true,
          'status': status,
          'message': status == 'pending'
              ? 'Đã tìm thấy lớp ${cloudClass['name']} và gửi yêu cầu tham gia. Vui lòng chờ giáo viên duyệt.'
              : 'Bạn đã tham gia lớp ${cloudClass['name']} thành công!',
          'classItem': cloudClass,
        };
      }
    } catch (_) {}

    String norm(String s) =>
        s.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final cleanNorm = norm(cleanCode);

    final classes = await getClasses();
    final targetClass = classes
        .where(
          (c) =>
              norm(
                (c['code'] ?? c['joinCode'] ?? c['join_code'] ?? '').toString(),
              ) ==
              cleanNorm,
        )
        .firstOrNull;

    if (targetClass == null) {
      return {
        'ok': false,
        'message':
            'Không tìm thấy lớp học với mã "$cleanCode". '
            'Vui lòng kiểm tra lại mã lớp hoặc yêu cầu giáo viên mở tab Lớp học trên điện thoại để đồng bộ lên hệ thống trước.',
      };
    }
    if (targetClass['allowJoin'] == false ||
        targetClass['status'] == 'archived') {
      return {
        'ok': false,
        'message': 'Lớp học này hiện đã đóng nhận học sinh mới.',
      };
    }

    final classId = targetClass['id'].toString();
    final requireApproval = targetClass['requireApproval'] == true;
    final status = requireApproval ? 'pending' : 'approved';

    final stats = await _repo.getOverallStats();
    final totalDone = (stats['totalDone'] as num?)?.toInt() ?? 0;
    final totalCorrect = (stats['totalCorrect'] as num?)?.toInt() ?? 0;
    final avgScore = totalDone > 0
        ? double.parse(((totalCorrect / totalDone) * 10).toStringAsFixed(1))
        : 0.0;
    final streakDays = (stats['streak'] as num?)?.toInt() ?? 0;

    final members = await getClassMembers(classId, syncRemote: false);
    final existingIdx = members.indexWhere(
      (m) =>
          m['studentId'] == studentId ||
          (studentEmail.isNotEmpty && m['studentEmail'] == studentEmail),
    );
    final memberItem = {
      'id': existingIdx >= 0
          ? members[existingIdx]['id']
          : 'cm_${DateTime.now().millisecondsSinceEpoch}',
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'status': status,
      'streakDays': streakDays,
      'avgScore': avgScore,
      'overdueCount': 0,
      'joinedAt': DateTime.now().toIso8601String(),
    };

    if (existingIdx >= 0) {
      members[existingIdx] = memberItem;
    } else {
      members.insert(0, memberItem);
    }
    await _saveClassMembersLocal(classId, members);

    // Cập nhật danh sách lớp học của học sinh vào cache
    final myJoined = await getMyJoinedClasses();
    final jIdx = myJoined.indexWhere((c) => c['id'] == targetClass['id']);
    final updatedTarget = Map<String, dynamic>.from(targetClass);
    updatedTarget['membershipStatus'] = status;
    if (jIdx >= 0) {
      myJoined[jIdx] = updatedTarget;
    } else {
      myJoined.insert(0, updatedTarget);
    }
    await _repo.setSetting('student_joined_classes_json', jsonEncode(myJoined));

    // Cập nhật sĩ số lớp học
    await getClasses();

    await recordAuditLog(
      action: 'STUDENT_JOIN_CLASS',
      targetType: 'class',
      targetId: classId,
      details:
          '$studentName tham gia lớp ${targetClass['name']} bằng mã $cleanCode ($status)',
    );

    return {
      'ok': true,
      'status': status,
      'message': status == 'pending'
          ? 'Đã gửi yêu cầu vào lớp ${targetClass['name']}. Vui lòng chờ giáo viên duyệt.'
          : 'Bạn đã vào lớp ${targetClass['name']} thành công!',
      'classItem': targetClass,
    };
  }

  Future<List<Map<String, dynamic>>> getClassMembers(
    String classId, {
    bool syncRemote = true,
  }) async {
    final raw = await _repo.getSetting('class_members_$classId');
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    if (syncRemote) {
      try {
        final client = await _client();
        final res = await client.getJson(
          '/classes/$classId/members',
          timeout: const Duration(seconds: 5),
        );
        if (res.isSuccess && res.data?['members'] is List) {
          final serverList = (res.data!['members'] as List).map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return {
              'id': (m['id'] ?? '').toString(),
              'classId': (m['class_id'] ?? m['classId'] ?? classId).toString(),
              'studentId': (m['student_id'] ?? m['studentId'] ?? '').toString(),
              'studentName': (m['student_name'] ?? m['studentName'] ?? '')
                  .toString(),
              'studentEmail': (m['student_email'] ?? m['studentEmail'] ?? '')
                  .toString(),
              'status': (m['status'] ?? 'approved').toString(),
              'streakDays': (m['streak_days'] ?? m['streakDays'] ?? 0 as num)
                  .toInt(),
              'avgScore': (m['avg_score'] ?? m['avgScore'] ?? 0.0 as num)
                  .toDouble(),
              'overdueCount':
                  (m['overdue_count'] ?? m['overdueCount'] ?? 0 as num).toInt(),
              'joinedAt':
                  (m['joined_at'] ??
                          m['joinedAt'] ??
                          DateTime.now().toIso8601String())
                      .toString(),
            };
          }).toList();
          if (serverList.isNotEmpty) {
            list = serverList;
            await _saveClassMembersLocal(classId, list);
          }
        }
      } catch (_) {}
    }

    // Lọc bỏ triệt để các yêu cầu duyệt giáo viên mock/ảo cũ
    final origReqLen = list.length;
    list.removeWhere((r) {
      final em = (r['email'] ?? '').toString().trim().toLowerCase();
      final id = (r['id'] ?? '').toString().trim().toLowerCase();
      return id.contains('mock') ||
          id.contains('pending_1') ||
          id.contains('pending_2') ||
          em.contains('mock') ||
          em.contains('example.com') ||
          em.contains('test');
    });
    if (list.length != origReqLen) {
      await _repo.setSetting('admin_teacher_requests_json', jsonEncode(list));
    }

    return list;
  }

  Future<void> _saveClassMembersLocal(
    String classId,
    List<Map<String, dynamic>> members,
  ) async {
    await _repo.setSetting('class_members_$classId', jsonEncode(members));
  }

  /// Giáo viên thêm học sinh vào lớp hoặc duyệt yêu cầu vào lớp
  Future<Map<String, dynamic>> addStudentToClass({
    required String classId,
    required String studentName,
    required String studentEmail,
    String status = 'approved',
  }) async {
    final members = await getClassMembers(classId, syncRemote: false);
    final item = {
      'id': 'cm_${DateTime.now().millisecondsSinceEpoch}',
      'classId': classId,
      'studentId': 'usr_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'status': status,
      'streakDays': 0,
      'avgScore': 0.0,
      'overdueCount': 0,
      'joinedAt': DateTime.now().toIso8601String(),
    };
    members.insert(0, item);
    await _saveClassMembersLocal(classId, members);
    await getClasses();
    return item;
  }

  Future<void> decideClassMember({
    required String classId,
    required String memberId,
    required String status, // 'approved' | 'rejected'
  }) async {
    final members = await getClassMembers(classId, syncRemote: false);
    if (status == 'rejected') {
      members.removeWhere((m) => m['id'] == memberId);
    } else {
      final idx = members.indexWhere((m) => m['id'] == memberId);
      if (idx >= 0) {
        members[idx]['status'] = status;
      }
    }
    await _saveClassMembersLocal(classId, members);
    await getClasses();

    await recordAuditLog(
      action: status == 'approved'
          ? 'APPROVE_CLASS_MEMBER'
          : 'REJECT_CLASS_MEMBER',
      targetType: 'class_member',
      targetId: memberId,
      details:
          '${status == 'approved' ? "Duyệt" : "Từ chối"} học sinh $memberId vào lớp $classId',
    );

    try {
      final client = await _client();
      await client.postJson('/classes/$classId/members/$memberId/decision', {
        'status': status,
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _getAssignmentsRaw() async {
    final raw = await _repo.getSetting('class_assignments_json');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Quản lý Bài giao cho lớp (Assignments CRUD)
  Future<List<Map<String, dynamic>>> getAssignments({String? classId}) async {
    List<Map<String, dynamic>> list = await _getAssignmentsRaw();

    try {
      final client = await _client();
      final q = classId != null && classId.isNotEmpty
          ? '?classId=$classId'
          : '';
      final res = await client.getJson(
        '/assignments$q',
        timeout: const Duration(seconds: 5),
      );
      if (res.isSuccess && res.data?['assignments'] is List) {
        final serverList = (res.data!['assignments'] as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {
            'id': (m['id'] ?? '').toString(),
            'title': (m['title'] ?? '').toString(),
            'classId': (m['class_id'] ?? m['classId'] ?? '').toString(),
            'className': (m['class_name'] ?? m['className'] ?? '').toString(),
            'contentType': (m['content_type'] ?? m['contentType'] ?? 'unit')
                .toString(),
            'unitNumber': (m['unit_number'] ?? m['unitNumber'] ?? 1 as num)
                .toInt(),
            'skills':
                (m['skills'] as List?)?.map((s) => s.toString()).toList() ??
                ['reading'],
            'dueAt':
                (m['due_at'] ??
                        m['dueAt'] ??
                        DateTime.now()
                            .add(const Duration(days: 3))
                            .toIso8601String())
                    .toString(),
            'maxAttempts': (m['max_attempts'] ?? m['maxAttempts'] ?? 2 as num)
                .toInt(),
            'showAnswerMode':
                (m['show_answer_mode'] ?? m['showAnswerMode'] ?? 'after_submit')
                    .toString(),
            'status': (m['status'] ?? 'open').toString(),
            'submittedCount':
                (m['submitted_count'] ?? m['submittedCount'] ?? 0 as num)
                    .toInt(),
            'createdAt':
                (m['created_at'] ??
                        m['createdAt'] ??
                        DateTime.now().toIso8601String())
                    .toString(),
          };
        }).toList();
        if (serverList.isNotEmpty) {
          for (final sa in serverList) {
            final idx = list.indexWhere((l) => l['id'] == sa['id']);
            if (idx >= 0) {
              list[idx] = sa;
            } else {
              list.add(sa);
            }
          }
          await _repo.setSetting('class_assignments_json', jsonEncode(list));
        }
      }
    } catch (_) {}

    final submissions = await getSubmissionsForClass();
    for (int i = 0; i < list.length; i++) {
      final a = Map<String, dynamic>.from(list[i]);
      final aid = a['id'].toString();
      final subCount = submissions
          .where((s) => s['assignmentId'] == aid)
          .length;
      if (subCount > 0) {
        a['submittedCount'] = subCount;
      }
      list[i] = a;
    }

    if (classId != null && classId.isNotEmpty && classId != 'all') {
      return list.where((a) => a['classId'] == classId).toList();
    }
    // Lọc bỏ triệt để các yêu cầu duyệt giáo viên mock/ảo cũ
    final origReqLen = list.length;
    list.removeWhere((r) {
      final em = (r['email'] ?? '').toString().trim().toLowerCase();
      final id = (r['id'] ?? '').toString().trim().toLowerCase();
      return id.contains('mock') ||
          id.contains('pending_1') ||
          id.contains('pending_2') ||
          em.contains('mock') ||
          em.contains('example.com') ||
          em.contains('test');
    });
    if (list.length != origReqLen) {
      await _repo.setSetting('admin_teacher_requests_json', jsonEncode(list));
    }

    return list;
  }

  Future<Map<String, dynamic>> createAssignment({
    required String title,
    required String classId,
    required String className,
    String contentType = 'unit',
    int unitNumber = 1,
    List<String> skills = const ['reading'],
    required DateTime dueAt,
    int maxAttempts = 2,
    String showAnswerMode = 'after_submit',
    String status = 'open',
  }) async {
    final list = await _getAssignmentsRaw();
    final item = {
      'id': 'asg_${DateTime.now().millisecondsSinceEpoch}',
      'title': title.trim(),
      'classId': classId,
      'className': className,
      'contentType': contentType,
      'unitNumber': unitNumber,
      'skills': skills,
      'dueAt': dueAt.toIso8601String(),
      'maxAttempts': maxAttempts,
      'showAnswerMode': showAnswerMode,
      'status': status,
      'submittedCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
    list.insert(0, item);
    await _repo.setSetting('class_assignments_json', jsonEncode(list));

    await recordAuditLog(
      action: 'CREATE_ASSIGNMENT',
      targetType: 'assignment',
      targetId: item['id'].toString(),
      details:
          'Giao bài "${item['title']}" cho lớp $className (Unit $unitNumber)',
    );

    try {
      final client = await _client();
      await client.postJson('/assignments', item);
    } catch (_) {}

    return item;
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final list = await _getAssignmentsRaw();
    list.removeWhere((a) => a['id'] == assignmentId);
    await _repo.setSetting('class_assignments_json', jsonEncode(list));
    try {
      final client = await _client();
      await client.deleteJson('/assignments/$assignmentId');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> submitAssignment({
    required String assignmentId,
    required String classId,
    required double score,
    int durationSeconds = 300,
    Map<String, double> skillScores = const {},
  }) async {
    final user = await _repo.getAuthUser();
    final raw = await _repo.getSetting('assignment_submissions_json');
    List<Map<String, dynamic>> subs = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        subs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    final subItem = {
      'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
      'assignmentId': assignmentId,
      'classId': classId,
      'studentId': user?.id ?? 'usr_student',
      'studentName': user?.displayName ?? 'Học sinh',
      'studentEmail': user?.email ?? '',
      'score': score,
      'durationSeconds': durationSeconds,
      'skillScores': skillScores,
      'status': 'submitted',
      'submittedAt': DateTime.now().toIso8601String(),
    };

    subs.insert(0, subItem);
    await _repo.setSetting('assignment_submissions_json', jsonEncode(subs));

    try {
      final client = await _client();
      await client.postJson('/assignments/$assignmentId/submit', subItem);
    } catch (_) {}

    return subItem;
  }

  Future<List<Map<String, dynamic>>> getSubmissionsForClass({
    String? classId,
    String? assignmentId,
  }) async {
    final raw = await _repo.getSetting('assignment_submissions_json');
    List<Map<String, dynamic>> subs = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        subs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    // Kết hợp thêm các bài nộp thật từ Phòng thi có giám sát (ExamLiveSessionModel)
    final rawSessions = await _repo.getSetting('exam_live_sessions_json');
    if (rawSessions != null && rawSessions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSessions) as List;
        final exams = await getSupervisedExams();
        for (final s in decoded) {
          final m = Map<String, dynamic>.from(s as Map);
          if (m['submittedAt'] != null) {
            final ex = exams.where((e) => e.id == m['examId']).firstOrNull;
            final exClassId = ex?.classId ?? '';
            final sessionSubId = 'exam_sub_${m['id']}';
            if (!subs.any((x) => x['id'] == sessionSubId)) {
              subs.add({
                'id': sessionSubId,
                'assignmentId': m['examId'] ?? '',
                'classId': exClassId,
                'studentId': m['userId'] ?? '',
                'studentName': m['studentName'] ?? 'Học sinh',
                'studentEmail': m['studentEmail'] ?? '',
                'score': (m['score'] as num?)?.toDouble() ?? 0.0,
                'durationSeconds': 600,
                'skillScores': <String, double>{},
                'status': m['status'] ?? 'submitted',
                'submittedAt': m['submittedAt'].toString(),
              });
            }
          }
        }
      } catch (_) {}
    }

    return subs.where((s) {
      if (classId != null &&
          classId.isNotEmpty &&
          classId != 'all' &&
          s['classId'] != classId) {
        return false;
      }
      if (assignmentId != null &&
          assignmentId.isNotEmpty &&
          s['assignmentId'] != assignmentId) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Quản lý Báo lỗi Câu hỏi / Bài đọc thật từ Học sinh & Giáo viên
  Future<List<Map<String, dynamic>>> getBugReports() async {
    final raw = await _repo.getSetting('admin_bug_reports_json');
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    try {
      final client = await _client();
      final res = await client.getJson(
        '/bug-reports',
        timeout: const Duration(seconds: 5),
      );
      if (res.isSuccess && res.data?['reports'] is List) {
        final serverList = (res.data!['reports'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (serverList.isNotEmpty) {
          for (final sr in serverList) {
            if (!list.any((l) => l['id'] == sr['id'])) {
              list.add(sr);
            }
          }
          await _repo.setSetting('admin_bug_reports_json', jsonEncode(list));
        }
      }
    } catch (_) {}

    // Lọc bỏ triệt để các yêu cầu duyệt giáo viên mock/ảo cũ
    final origReqLen = list.length;
    list.removeWhere((r) {
      final em = (r['email'] ?? '').toString().trim().toLowerCase();
      final id = (r['id'] ?? '').toString().trim().toLowerCase();
      return id.contains('mock') ||
          id.contains('pending_1') ||
          id.contains('pending_2') ||
          em.contains('mock') ||
          em.contains('example.com') ||
          em.contains('test');
    });
    if (list.length != origReqLen) {
      await _repo.setSetting('admin_teacher_requests_json', jsonEncode(list));
    }

    return list;
  }

  Future<Map<String, dynamic>> submitBugReport({
    required String targetCode,
    required int unitNumber,
    required String skill,
    required String issueType,
    required String reason,
    String questionId = '',
  }) async {
    final user = await _repo.getAuthUser();
    final list = await getBugReports();
    final item = {
      'id': 'rpt_${DateTime.now().millisecondsSinceEpoch}',
      'targetCode': targetCode.trim(),
      'questionId': questionId,
      'unit': unitNumber,
      'skill': skill,
      'issueType': issueType,
      'reason': reason.trim(),
      'reporter': user?.displayName.isNotEmpty == true
          ? user!.displayName
          : (user?.email ?? 'Học sinh'),
      'status': 'open',
      'reportCount': 1,
      'createdAt': DateTime.now().toIso8601String(),
    };
    list.insert(0, item);
    await _repo.setSetting('admin_bug_reports_json', jsonEncode(list));

    await recordAuditLog(
      action: 'SUBMIT_BUG_REPORT',
      targetType: 'question_bug_report',
      targetId: item['id'].toString(),
      details: 'Báo lỗi "$targetCode" ($issueType): ${reason.trim()}',
    );

    try {
      final client = await _client();
      await client.postJson('/bug-reports', {
        'targetCode': targetCode.trim(),
        'questionId': questionId,
        'unitNumber': unitNumber,
        'skill': skill,
        'issueType': issueType,
        'reason': reason.trim(),
        'reporterName': item['reporter'],
      });
    } catch (_) {}

    return item;
  }

  Future<void> updateBugReportStatus({
    required String reportId,
    required String status, // 'open' | 'fixed' | 'ignored'
  }) async {
    final list = await getBugReports();
    final idx = list.indexWhere((r) => r['id'] == reportId);
    if (idx >= 0) {
      list[idx]['status'] = status;
      await _repo.setSetting('admin_bug_reports_json', jsonEncode(list));
    }

    await recordAuditLog(
      action: 'RESOLVE_BUG_REPORT',
      targetType: 'question_bug_report',
      targetId: reportId,
      details: 'Cập nhật trạng thái báo lỗi $reportId sang "$status"',
    );

    try {
      final client = await _client();
      await client.putJson('/bug-reports/$reportId', {'status': status});
    } catch (_) {}
  }

  /// Quản lý Thông báo hệ thống thật
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final raw = await _repo.getSetting('admin_announcements_json');
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    try {
      final client = await _client();
      final res = await client.getJson(
        '/announcements',
        timeout: const Duration(seconds: 5),
      );
      if (res.isSuccess && res.data?['announcements'] is List) {
        final serverList = (res.data!['announcements'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (serverList.isNotEmpty) {
          for (final sa in serverList) {
            if (!list.any((l) => l['id'] == sa['id'])) {
              list.add(sa);
            }
          }
          await _repo.setSetting('admin_announcements_json', jsonEncode(list));
        }
      }
    } catch (_) {}

    return list;
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    String audience = 'Tất cả người dùng',
    String category = 'Hệ thống',
    String displayType = 'Cả hai',
    bool sendPush = true,
    String scheduledAt = 'Gửi ngay',
  }) async {
    final list = await getAnnouncements();
    final nowIso = DateTime.now().toIso8601String();
    final item = {
      'id': 'ann_${DateTime.now().millisecondsSinceEpoch}',
      'title': title.trim(),
      'content': content.trim(),
      'audience': audience,
      'target': audience,
      'category': category,
      'type': category,
      'displayType': displayType,
      'sendPush': sendPush,
      'scheduledAt': scheduledAt,
      'sentAt': nowIso,
      'createdAt': nowIso,
    };
    list.insert(0, item);
    await _repo.setSetting('admin_announcements_json', jsonEncode(list));

    await recordAuditLog(
      action: 'SEND_SYSTEM_ANNOUNCEMENT',
      targetType: 'announcement',
      targetId: item['id'].toString(),
      details: 'Gửi thông báo "$title" tới $audience',
    );

    try {
      final client = await _client();
      await client.postJson('/announcements', {
        'title': title.trim(),
        'content': content.trim(),
        'target': audience,
        'type': category,
      });
    } catch (_) {}

    return item;
  }

  /// Quản lý Yêu cầu Duyệt tài khoản Giáo viên thật (Không tự tạo giáo viên mẫu giả)
  Future<List<Map<String, dynamic>>> getTeacherRequests() async {
    final raw = await _repo.getSetting('admin_teacher_requests_json');
    List<Map<String, dynamic>> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    try {
      final client = await _client();
      final res = await client.getJson(
        '/admin/teacher-requests',
        timeout: const Duration(seconds: 5),
      );
      if (res.isSuccess && res.data?['requests'] is List) {
        final serverList = (res.data!['requests'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (serverList.isNotEmpty) {
          list = serverList;
          await _repo.setSetting(
            'admin_teacher_requests_json',
            jsonEncode(list),
          );
        }
      }
    } catch (_) {}

    // Lọc bỏ triệt để các yêu cầu duyệt giáo viên mock/ảo cũ
    final origReqLen = list.length;
    list.removeWhere((r) {
      final em = (r['email'] ?? '').toString().trim().toLowerCase();
      final id = (r['id'] ?? '').toString().trim().toLowerCase();
      return id.contains('mock') ||
          id.contains('pending_1') ||
          id.contains('pending_2') ||
          em.contains('mock') ||
          em.contains('example.com') ||
          em.contains('test');
    });
    if (list.length != origReqLen) {
      await _repo.setSetting('admin_teacher_requests_json', jsonEncode(list));
    }

    return list;
  }

  Future<void> decideTeacherRequest({
    required Map<String, dynamic> request,
    required bool approve,
    String password = '',
  }) async {
    final requests = await getTeacherRequests();
    requests.removeWhere((r) => r['id'] == request['id']);
    await _repo.setSetting('admin_teacher_requests_json', jsonEncode(requests));

    if (approve) {
      final pwd = password.trim().isNotEmpty
          ? password.trim()
          : 'GV${DateTime.now().millisecondsSinceEpoch % 100000}!';
      await createAdminUser(
        email: (request['email'] ?? '').toString(),
        password: pwd,
        displayName: (request['display_name'] ?? request['displayName'] ?? '')
            .toString(),
        role: 'teacher',
      );
    } else {
      await recordAuditLog(
        action: 'REJECT_TEACHER_REQUEST',
        targetType: 'teacher_request',
        targetId: (request['id'] ?? '').toString(),
        details: 'Từ chối yêu cầu tài khoản giáo viên: ${request['email']}',
      );
    }

    try {
      final client = await _client();
      await client.postJson(
        '/admin/teacher-requests/${request['id']}/decision',
        {'approve': approve},
      );
    } catch (_) {}
  }

  // ===========================================================================
  // 12. QUẢN LÝ LỊCH NHẮC HẸN LỚP HỌC (CLASS REMINDERS) & THÔNG BÁO TỚI HỌC VIÊN
  // ===========================================================================

  /// Lấy danh sách Lịch nhắc hẹn của Lớp học (hỗ trợ lọc theo classId)
  Future<List<ClassReminderModel>> getClassReminders({String? classId}) async {
    final raw = await _repo.getSetting('class_reminders_json');
    List<ClassReminderModel> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        list = decoded
            .map(
              (e) => ClassReminderModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {}
    }

    // Thử đồng bộ từ Backend Render nếu có kết nối
    try {
      final client = await _client();
      final res = await client.getJson(
        '/announcements',
        timeout: const Duration(seconds: 4),
      );
      if (res.isSuccess && res.data?['announcements'] is List) {
        final serverList = (res.data!['announcements'] as List)
            .where((a) => (a['type'] ?? '') == 'class_reminder')
            .map(
              (a) => ClassReminderModel.fromMap(
                Map<String, dynamic>.from(a as Map),
              ),
            )
            .toList();
        for (final sItem in serverList) {
          if (!list.any((l) => l.id == sItem.id)) {
            list.add(sItem);
          }
        }
        await _repo.setSetting(
          'class_reminders_json',
          jsonEncode(list.map((e) => e.toMap()).toList()),
        );
      }
    } catch (_) {}

    // Sắp xếp theo ngày giờ hẹn tăng dần
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (classId != null && classId.isNotEmpty) {
      return list.where((r) => r.classId == classId).toList();
    }
    return list;
  }

  /// Giáo viên tạo Lịch nhắc hẹn cho toàn bộ học sinh trong Lớp học
  Future<ClassReminderModel> createClassReminder({
    required String classId,
    required String className,
    required String title,
    required String message,
    required DateTime scheduledAt,
    String? teacherName,
    String? teacherEmail,
  }) async {
    final user = await _repo.getAuthUser();
    final cleanTeacherName =
        teacherName ??
        (user?.displayName.isNotEmpty == true
            ? user!.displayName
            : 'Giáo viên');
    final cleanTeacherEmail = teacherEmail ?? (user?.email ?? '');

    final reminder = ClassReminderModel(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      classId: classId,
      className: className,
      title: title.trim(),
      message: message.trim(),
      scheduledAt: scheduledAt,
      teacherName: cleanTeacherName,
      teacherEmail: cleanTeacherEmail,
      createdAt: DateTime.now(),
      isActive: true,
    );

    final list = await getClassReminders();
    list.insert(0, reminder);
    await _repo.setSetting(
      'class_reminders_json',
      jsonEncode(list.map((e) => e.toMap()).toList()),
    );

    // Đồng bộ lên Backend Render qua hệ thống Announcements
    try {
      final client = await _client();
      await client.postJson('/announcements', {
        'id': reminder.id,
        'title': reminder.title,
        'content': reminder.message,
        'target': 'class',
        'type': 'class_reminder',
        'class_id': reminder.classId,
        'class_name': reminder.className,
        'remind_at': reminder.scheduledAt.toIso8601String(),
        'sent_by': reminder.teacherName,
      });
    } catch (_) {}

    // Lên lịch trực tiếp trên điện thoại này (để máy hiện tại cũng nhận thông báo khi tới giờ)
    await NotificationService().scheduleClassReminder(
      id: reminder.notificationId,
      title: '🔔 ${reminder.className}: ${reminder.title}',
      body: reminder.message,
      scheduledDate: reminder.scheduledAt,
      payload: 'class_reminder_${reminder.id}',
    );

    await recordAuditLog(
      action: 'CREATE_CLASS_REMINDER',
      targetType: 'class_reminder',
      targetId: reminder.id,
      details:
          '$cleanTeacherName tạo lịch nhắc hẹn "$title" cho $className lúc ${scheduledAt.toIso8601String()}',
    );

    return reminder;
  }

  /// Hủy lịch nhắc hẹn
  Future<void> deleteClassReminder(String reminderId) async {
    final list = await getClassReminders();
    final idx = list.indexWhere((r) => r.id == reminderId);
    if (idx >= 0) {
      final item = list[idx];
      await NotificationService().cancelNotification(item.notificationId);
      list.removeAt(idx);
      await _repo.setSetting(
        'class_reminders_json',
        jsonEncode(list.map((e) => e.toMap()).toList()),
      );
    }
  }

  /// Học viên đồng bộ lịch nhắc hẹn từ các lớp học mình tham gia vào hệ điều hành
  Future<int> syncStudentClassReminders(String userId) async {
    final myClasses = await getMyJoinedClasses();
    final joinedClassIds = myClasses
        .map((c) => (c['id'] ?? '').toString())
        .toSet();
    final allReminders = await getClassReminders();

    int scheduledCount = 0;
    for (final reminder in allReminders) {
      if (!reminder.isActive) continue;
      // Nếu học sinh thuộc lớp này (hoặc chưa phân lớp nhưng có lịch demo)
      final isMember =
          joinedClassIds.isEmpty || joinedClassIds.contains(reminder.classId);
      if (isMember && reminder.scheduledAt.isAfter(DateTime.now())) {
        final success = await NotificationService().scheduleClassReminder(
          id: reminder.notificationId,
          title: '🔔 ${reminder.className}: ${reminder.title}',
          body: reminder.message,
          scheduledDate: reminder.scheduledAt,
          payload: 'class_reminder_${reminder.id}',
        );
        if (success) scheduledCount++;
      }
    }
    return scheduledCount;
  }

  /// Đồng bộ một mục bài học đã hoàn thành của học sinh lên Cloud PostgreSQL
  Future<bool> syncTextbookProgressToCloud({
    required int unitNumber,
    required String sectionKey,
    String status = 'completed',
    int score = 100,
  }) async {
    final user = await _repo.getAuthUser();
    final userId = user?.id ?? 'usr_local';
    final userEmail = user?.email ?? '';

    try {
      final client = await _client();
      final res = await client.postJson('/students/progress/sync', {
        'userId': userId,
        'userEmail': userEmail,
        'unitNumber': unitNumber,
        'sectionName': sectionKey,
        'status': status,
        'score': score,
      });
      return res.isSuccess;
    } catch (_) {
      return false;
    }
  }

  /// Tra cứu tiến độ học tập chi tiết của học sinh từ Cloud Render
  Future<Map<String, dynamic>?> getStudentCloudProgress(
    String identifier,
  ) async {
    if (identifier.trim().isEmpty) return null;
    try {
      final client = await _client();
      final res = await client.getJson(
        '/students/${Uri.encodeComponent(identifier.trim())}/progress',
        timeout: const Duration(seconds: 5),
      );
      if (res.isSuccess && res.data != null) {
        return Map<String, dynamic>.from(res.data!);
      }
    } catch (_) {}
    return null;
  }

  /// Đồng bộ toàn diện toàn bộ tiến độ học tập 10 Unit SGK từ thiết bị lên Cloud PostgreSQL
  Future<int> syncAllStudentProgressToCloud() async {
    final user = await _repo.getAuthUser();
    if (user == null || user.isGuest) return 0;
    final userId = user.id;
    final userEmail = user.email.toLowerCase().trim();

    final sectionsToSync = <Map<String, dynamic>>[];
    const sectionKeys = [
      'getting_started',
      'language',
      'reading',
      'listening',
      'speaking',
      'writing',
      'communication_culture',
      'looking_back',
    ];

    // 1. Quét tiến độ 10 Unit SGK từ local SQLite
    for (int u = 1; u <= 10; u++) {
      // Kiểm tra bài học thử đọc hiểu trial
      final trialDone = await _repo.getCompletedTrialLessonId(userId);
      final trialEmailDone = userEmail.isNotEmpty
          ? await _repo.getCompletedTrialLessonId(userEmail)
          : null;
      if (trialDone == 'trial_unit${u}_reading' ||
          trialEmailDone == 'trial_unit${u}_reading') {
        sectionsToSync.add({
          'unitNumber': u,
          'sectionName': 'reading',
          'status': 'completed',
          'score': 100,
        });
      }

      for (final sec in sectionKeys) {
        final pId = await _repo.getSetting(
          'unit_section_progress_${userId}_u${u}_$sec',
        );
        final pEmail = userEmail.isNotEmpty
            ? await _repo.getSetting(
                'unit_section_progress_${userEmail}_u${u}_$sec',
              )
            : null;
        if (pId == 'completed' || pEmail == 'completed') {
          sectionsToSync.add({
            'unitNumber': u,
            'sectionName': sec,
            'status': 'completed',
            'score': 100,
          });
        }
      }
    }

    // 2. Lấy số ngày streak và điểm trung bình
    final summary = await _repo.getOverallStats(ownerId: userId);
    final streak = (summary['streak'] as num?)?.toInt() ?? 0;
    final totalDone = (summary['totalDone'] as num?)?.toInt() ?? 0;
    final totalCorrect = (summary['totalCorrect'] as num?)?.toInt() ?? 0;
    final avgScore = totalDone > 0 ? (totalCorrect / totalDone * 10) : 0.0;

    // 3. Gửi lên Cloud Render
    try {
      final client = await _client();
      final res = await client.postJson('/students/progress/batch-sync', {
        'userId': userId,
        'userEmail': userEmail,
        'streak': streak,
        'totalXp': totalCorrect * 10,
        'avgScore': avgScore,
        'sections': sectionsToSync,
      });
      if (res.isSuccess) {
        return (res.data?['syncedCount'] as num?)?.toInt() ??
            sectionsToSync.length;
      }
    } catch (_) {}

    return sectionsToSync.length;
  }

  /// Kiểm tra trạng thái khóa tài khoản thời gian thực từ Cloud PostgreSQL
  Future<Map<String, dynamic>> checkRemoteAccountLockStatus(
    String email, {
    String? userId,
  }) async {
    if (email.trim().isEmpty && (userId == null || userId.trim().isEmpty)) {
      return {'isLocked': false};
    }
    try {
      final client = await _client();
      final q = <String>[];
      if (email.trim().isNotEmpty)
        q.add('email=${Uri.encodeComponent(email.trim())}');
      if (userId != null && userId.trim().isNotEmpty)
        q.add('userId=${Uri.encodeComponent(userId.trim())}');
      final res = await client.getJson(
        '/auth/check-lock?${q.join('&')}',
        timeout: const Duration(seconds: 4),
      );
      if (res.isSuccess && res.data != null) {
        return {
          'isLocked': res.data!['isLocked'] == true,
          'lockedReason': res.data!['lockedReason']?.toString() ?? '',
        };
      }
    } catch (_) {}
    return {'isLocked': false};
  }
}
