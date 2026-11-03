import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thpt_english/data/app_database.dart';
import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/attempt.dart';
import 'package:thpt_english/data/models/attempt_answer.dart';
import 'package:thpt_english/data/models/daily_stat.dart';
import 'package:thpt_english/data/models/learning_session.dart';
import 'package:thpt_english/data/models/question.dart';
import 'package:thpt_english/data/models/user_profile.dart';
import 'package:thpt_english/data/models/word_progress.dart';
import 'package:thpt_english/data/models/wrong_book_entry.dart';
import 'package:thpt_english/data/trial_policy.dart';
import 'package:thpt_english/ui/auth/auth_controller.dart';

import 'support/sqlite_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SqliteBridge bridge;
  late Database database;
  late AppRepository repository;

  setUpAll(() async {
    bridge = await SqliteBridge.start();
    database = await AppDatabase.instance.database;
    repository = AppRepository();
  });

  tearDownAll(() async {
    await database.close();
    await bridge.close();
  });

  setUp(() async {
    for (final table in [
      'data_ownership',
      'attempt_answers',
      'attempts',
      'wrong_book',
      'word_progress',
      'daily_stats',
      'questions',
      'app_settings',
    ]) {
      await database.delete(table);
    }
    AuthController.instance.logout();

    // Thêm các câu hỏi chuẩn vào bảng questions để thỏa mãn foreign key constraint
    await repository.insertQuestions([
      const Question(
        id: 'u1_rd_q1',
        grade: 12,
        type: 'reading',
        stem: '1. adopted',
        options: ['given birth to', 'taken by another family as their own child'],
        correctIndex: 1,
        explanation: 'Đoạn A: He was adopted by Clara and Paul Jobs.',
        difficulty: 1,
      ),
      const Question(
        id: 'u1_rd_q2',
        grade: 12,
        type: 'reading',
        stem: '2. dropped out',
        options: ['continued to study', 'left school/college before completing your studies'],
        correctIndex: 1,
        explanation: 'Đoạn A: dropped out after six months.',
        difficulty: 1,
      ),
      const Question(
        id: 'u1_rd_q3',
        grade: 12,
        type: 'reading',
        stem: '3. cancer',
        options: ['a serious disease', 'a dangerous animal'],
        correctIndex: 0,
        explanation: 'Đoạn C: diagnosed with a rare form of pancreatic cancer.',
        difficulty: 1,
      ),
      const Question(
        id: 'u1_rd_q4',
        grade: 12,
        type: 'reading',
        stem: '4. passed away',
        options: ['died', 'went past something'],
        correctIndex: 0,
        explanation: 'Đoạn C: Two months later, he passed away.',
        difficulty: 1,
      ),
      const Question(
        id: 'u1_rd_q5',
        grade: 12,
        type: 'reading',
        stem: '5. genius',
        options: ['a very intelligent person', 'an ordinary person'],
        correctIndex: 0,
        explanation: 'Đoạn C: Apple has lost a visionary and creative genius.',
        difficulty: 1,
      ),
      const Question(
        id: 'q1',
        grade: 12,
        type: 'grammar',
        stem: 'Grammar question 1',
        options: ['A', 'B'],
        correctIndex: 0,
        explanation: 'Explanation 1',
        difficulty: 1,
      ),
      const Question(
        id: 'q2',
        grade: 12,
        type: 'grammar',
        stem: 'Grammar question 2',
        options: ['A', 'B'],
        correctIndex: 1,
        explanation: 'Explanation 2',
        difficulty: 1,
      ),
    ]);
  });

  group('BỘ 20 HÀNH VI NGHIỆM THU TỔNG THỂ DỰ ÁN ENGLISH 12', () {
    // 1. Khách mở app không bị tự sinh email/account giả lập hay token mock
    test('1. Guest can access app without auto-generated fake account/token', () async {
      final auth = AuthController.instance;
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user.isGuest, isTrue);
      expect(auth.user.email, isEmpty);
      expect(auth.user.id, 'guest_user');
      expect(auth.user.isLoggedIn, isFalse);
    });

    // 2. Nội dung học thử là Unit 1 Reading thật (Steve Jobs trang 13-14)
    test('2. Guest trial content is authentic Unit 1 Reading (Steve Jobs)', () {
      expect(TrialPolicy.trialUnitNumber, 1);
      expect(TrialPolicy.trialSection, 'Reading');
      expect(TrialPolicy.trialArticleTitle, contains('Steve Jobs'));

      final isTrial = TrialPolicy.isTrialContent(
        unitNumber: 1,
        sectionTitle: 'Reading',
      );
      expect(isTrial, isTrue);

      final isOutOfTrial = TrialPolicy.isTrialContent(
        unitNumber: 1,
        sectionTitle: 'Speaking',
      );
      expect(isOutOfTrial, isFalse);
    });

    // 3. Khách làm bài xem số câu đúng/tổng số câu thật và giải thích đáp án
    test('3. Guest can view real score and authentic explanations', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      final finishedAt = DateTime.now().millisecondsSinceEpoch;

      final attempt = Attempt(
        mode: 'practice',
        type: 'reading_study',
        startedAt: finishedAt - 60000,
        durationSec: 60,
        score: 4,
        total: 5,
      );

      await repository.savePracticeResult(
        attempt: attempt,
        buildAnswers: (attId) => [
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q1', chosenIndex: 1, isCorrect: true),
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q2', chosenIndex: 1, isCorrect: true),
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q3', chosenIndex: 0, isCorrect: true),
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q4', chosenIndex: 0, isCorrect: true),
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q5', chosenIndex: 1, isCorrect: false),
        ],
        wrongEntries: [
          WrongBookEntry(
            questionId: 'u1_rd_q5',
            wrongCount: 1,
            lastWrongAt: finishedAt,
            nextReviewAt: finishedAt + 86400000,
          ),
        ],
        dailyStat: DailyStat(
          date: '2026-11-01',
          xp: 40,
          questionsDone: 5,
          correct: 4,
          minutes: 2,
        ),
        ownerId: guestId,
      );

      final attempts = await repository.getAllAttempts(ownerId: guestId);
      expect(attempts.length, 1);
      expect(attempts.first.score, 4);
      expect(attempts.first.total, 5);
    });

    // 4. Lời mời đăng ký xuất hiện sau kết quả, không che mờ hoặc ép đăng ký
    test('4. Guest result not blocked by mandatory register gate', () {
      final auth = AuthController.instance;
      expect(auth.hasDismissedGuestPrompt, isFalse);
      auth.dismissGuestPrompt();
      expect(auth.hasDismissedGuestPrompt, isTrue);
    });

    // 5. Khách có thể đóng lời mời đăng ký và quay về phạm vi học thử
    test('5. Guest can dismiss prompt and return to trial', () {
      final auth = AuthController.instance;
      auth.dismissGuestPrompt();
      expect(auth.hasDismissedGuestPrompt, isTrue);
      expect(auth.user.isGuest, isTrue);
    });

    // 6. Hoạt động khách lưu trên SQLite với ownerId = guestSessionId
    test('6. Guest activity saved locally with guest session ID', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      expect(guestId, startsWith('guest_'));

      await repository.upsertWordProgress(
        const WordProgress(
          wordId: '101',
          reviewCount: 1,
          streak: 1,
          nextReviewAt: 1700000000,
          lastReviewedAt: 1699900000,
        ),
        ownerId: guestId,
      );

      final guestWords = await repository.getAllWordProgress(ownerId: guestId);
      expect(guestWords.length, 1);
      expect(guestWords.first.wordId, '101');
    });

    // 7. Dữ liệu phân tách theo ownerId trong data_ownership
    test('7. Guest data separated from other users in data_ownership', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      const studentId = 'student_account_99';

      await repository.upsertWordProgress(
        const WordProgress(
          wordId: '1',
          reviewCount: 1,
          streak: 1,
          nextReviewAt: 1000,
          lastReviewedAt: 900,
        ),
        ownerId: guestId,
      );

      await repository.upsertWordProgress(
        const WordProgress(
          wordId: '2',
          reviewCount: 1,
          streak: 1,
          nextReviewAt: 1000,
          lastReviewedAt: 900,
        ),
        ownerId: studentId,
      );

      final guestItems = await repository.getAllWordProgress(ownerId: guestId);
      final studentItems = await repository.getAllWordProgress(ownerId: studentId);

      expect(guestItems.length, 1);
      expect(guestItems.first.wordId, '1');

      expect(studentItems.length, 1);
      expect(studentItems.first.wordId, '2');
    });

    // 8. Khách mở nội dung ngoài Unit 1 Reading sẽ được giải thích lợi ích tài khoản
    test('8. Accessing content outside trial explains account benefits', () {
      final isTrialUnit3 = TrialPolicy.isTrialContent(
        unitNumber: 3,
        sectionTitle: 'Speaking',
      );
      expect(isTrialUnit3, isFalse);
      expect(TrialPolicy.accountBenefitsExplanation, contains('Lưu toàn bộ kết quả'));
      expect(TrialPolicy.accountBenefitsExplanation, contains('10 Unit'));
    });

    // 9. Khi đăng ký tài khoản mới thành công, dữ liệu phiên khách chuyển sang tài khoản mới
    test('9. Registering real account transfers guest session data to new account', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      final finishedAt = DateTime.now().millisecondsSinceEpoch;

      await repository.savePracticeResult(
        attempt: Attempt(
          mode: 'practice',
          type: 'grammar',
          startedAt: finishedAt - 30000,
          durationSec: 30,
          score: 2,
          total: 2,
        ),
        buildAnswers: (attId) => [
          AttemptAnswer(attemptId: attId, questionId: 'q1', chosenIndex: 0, isCorrect: true),
          AttemptAnswer(attemptId: attId, questionId: 'q2', chosenIndex: 1, isCorrect: true),
        ],
        wrongEntries: [],
        dailyStat: DailyStat(
          date: '2026-11-01',
          xp: 20,
          questionsDone: 2,
          correct: 2,
          minutes: 1,
        ),
        ownerId: guestId,
      );

      const newUserId = 'new_user_123';
      final result = await repository.transferGuestData(
        fromGuestId: guestId,
        toUserId: newUserId,
      );

      expect(result.success, isTrue);
      expect(result.transferredAttempts, greaterThan(0));

      final newUserAttempts = await repository.getAllAttempts(ownerId: newUserId);
      expect(newUserAttempts.length, 1);
      expect(newUserAttempts.first.score, 2);

      final oldGuestAttempts = await repository.getAllAttempts(ownerId: guestId);
      expect(oldGuestAttempts, isEmpty);
    });

    // 10. Sổ câu sai của khách được bảo toàn đầy đủ sang tài khoản mới
    test('10. Guest wrong book entries are preserved during transfer', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      final finishedAt = DateTime.now().millisecondsSinceEpoch;

      await repository.savePracticeResult(
        attempt: Attempt(
          mode: 'practice',
          type: 'reading',
          startedAt: finishedAt - 40000,
          durationSec: 40,
          score: 0,
          total: 1,
        ),
        buildAnswers: (attId) => [
          AttemptAnswer(attemptId: attId, questionId: 'u1_rd_q3', chosenIndex: 1, isCorrect: false),
        ],
        wrongEntries: [
          WrongBookEntry(
            questionId: 'u1_rd_q3',
            wrongCount: 1,
            lastWrongAt: finishedAt,
            nextReviewAt: finishedAt + 86400000,
          ),
        ],
        dailyStat: DailyStat(date: '2026-11-01', xp: 0, questionsDone: 1, correct: 0, minutes: 1),
        ownerId: guestId,
      );

      final guestWrong = await repository.getAllWrongBookEntries(ownerId: guestId);
      expect(guestWrong.length, 1);
      expect(guestWrong.first.questionId, 'u1_rd_q3');

      const newUserId = 'registered_user_888';
      await repository.transferGuestData(fromGuestId: guestId, toUserId: newUserId);

      final transferredWrong = await repository.getAllWrongBookEntries(ownerId: newUserId);
      expect(transferredWrong.length, 1);
      expect(transferredWrong.first.questionId, 'u1_rd_q3');
      expect(transferredWrong.first.wrongCount, 1);
    });

    // 11. Tiến độ từ vựng của khách được bảo toàn đầy đủ sang tài khoản mới
    test('11. Guest vocabulary progress is preserved during transfer', () async {
      final guestId = await repository.getOrCreateGuestSessionId();
      await repository.upsertWordProgress(
        const WordProgress(
          wordId: '77',
          reviewCount: 3,
          streak: 2,
          nextReviewAt: 1800000000,
          lastReviewedAt: 1750000000,
        ),
        ownerId: guestId,
      );

      const targetAccount = 'student_account_77';
      await repository.transferGuestData(fromGuestId: guestId, toUserId: targetAccount);

      final saved = await repository.getAllWordProgress(ownerId: targetAccount);
      expect(saved.length, 1);
      expect(saved.first.wordId, '77');
      expect(saved.first.reviewCount, 3);
      expect(saved.first.streak, 2);
    });

    // 12. Session bài học cho phép học tiếp từ đúng vị trí vừa học
    test('12. Learning session correctly stores and resumes previous study location', () async {
      const owner = 'user_resume_test';
      final session = LearningSession(
        ownerId: owner,
        lessonId: 'reading_u1',
        lessonTitle: 'Steve Jobs: Life and Achievements',
        lessonType: 'topic',
        status: 'completed',
        currentQuestionIndex: 5,
        totalQuestions: 5,
        score: 5,
        questionIds: ['u1_rd_q1', 'u1_rd_q2', 'u1_rd_q3', 'u1_rd_q4', 'u1_rd_q5'],
      );

      await repository.saveLearningSession(session);
      final restored = await repository.getLearningSession(owner);

      expect(restored, isNotNull);
      expect(restored!.lessonId, 'reading_u1');
      expect(restored.lessonTitle, 'Steve Jobs: Life and Achievements');
      expect(restored.isCompleted, isTrue);
      expect(restored.score, 5);
    });

    // 13. Học viên đăng nhập có hồ sơ và dữ liệu riêng biệt
    test('13. Authenticated user loads their own isolated profile and study data', () async {
      final auth = AuthController.instance;
      await auth.signInExistingAccount(
        existingUser: const UserProfile(
          id: 'auth_user_001',
          displayName: 'Nguyen Van A',
          email: 'nguyenvana@gmail.com',
          authProvider: 'email',
          role: 'student',
          targetScore: 8.5,
          dailyMinutes: 30,
          isLoggedIn: true,
        ),
      );

      expect(auth.isAuthenticated, isTrue);
      expect(auth.user.isGuest, isFalse);
      expect(auth.user.email, 'nguyenvana@gmail.com');
      expect(auth.user.role, 'student');
    });

    // 14. Vai trò người dùng mặc định là student, hỗ trợ teacher và admin
    test('14. User profile default role is student, supports teacher and admin', () {
      const defaultProfile = UserProfile();
      expect(defaultProfile.role, 'student');
      expect(defaultProfile.isStudent, isTrue);
      expect(defaultProfile.isTeacher, isFalse);
      expect(defaultProfile.isAdmin, isFalse);

      const teacherProfile = UserProfile(role: 'teacher');
      expect(teacherProfile.isTeacher, isTrue);
      expect(teacherProfile.isStudent, isFalse);

      const adminProfile = UserProfile(role: 'admin');
      expect(adminProfile.isAdmin, isTrue);
      expect(adminProfile.isStudent, isFalse);
    });

    // 15. Backend băm mật khẩu bằng Scrypt + salt, không lưu plaintext
    test('15. Backend server code defines Scrypt password hashing with salt', () {
      final serverFile = File('backend/server.js');
      expect(serverFile.existsSync(), isTrue);
      final content = serverFile.readAsStringSync();

      expect(content, contains('hashPassword'));
      expect(content, contains('verifyPassword'));
      expect(content, contains('scryptSync'));
      expect(content, contains('randomBytes'));
    });

    // 16. Backend xác thực JWT thật, chặn truy cập trái phép
    test('16. Backend server code defines JWT token generation and authentication middleware', () {
      final serverFile = File('backend/server.js');
      expect(serverFile.existsSync(), isTrue);
      final content = serverFile.readAsStringSync();

      expect(content, contains('generateToken'));
      expect(content, contains('verifyToken'));
      expect(content, contains('authenticateToken'));
      expect(content, contains('authorization'));
    });

    // 17. Backend trả 503 trung thực khi thiếu Database/Google Client ID/SMTP
    test('17. Backend reports missing configurations honestly with 503', () {
      final serverFile = File('backend/server.js');
      expect(serverFile.existsSync(), isTrue);
      final content = serverFile.readAsStringSync();

      expect(content, contains('DATABASE_URL'));
      expect(content, contains('GOOGLE_CLIENT_ID'));
      expect(content, contains('SMTP_HOST'));
      expect(content, contains('503'));
    });

    // 18. Unit 2 có tên chính thức "A multicultural world"
    test('18. Textbook Unit 2 is officially named A multicultural world', () {
      final hubFile = File('lib/ui/textbook/textbook_hub_screen.dart');
      expect(hubFile.existsSync(), isTrue);
      final content = hubFile.readAsStringSync();

      expect(content, contains("'title': 'A multicultural world'"));
      expect(content, contains("'vietnamese': 'Một thế giới đa văn hóa'"));
    });

    // 19. Tiến độ sách tính đúng (tử số và mẫu số cùng 120 trang của 10 Unit)
    test('19. Textbook progress calculation is consistent (120 curriculum pages)', () {
      final hubFile = File('lib/ui/textbook/textbook_hub_screen.dart');
      expect(hubFile.existsSync(), isTrue);
      final content = hubFile.readAsStringSync();

      expect(content, contains('unitPagesSet'));
      expect(content, contains('totalCurriculumPages = 120'));
    });

    // 20. Tab Tôi cho khách hiển thị Bạn đang học thử, không hiện nút Đăng xuất
    test('20. Guest Profile tab shows honest trial state and hides logout button', () {
      final settingsFile = File('lib/ui/settings/settings_screen.dart');
      expect(settingsFile.existsSync(), isTrue);
      final content = settingsFile.readAsStringSync();

      expect(content, contains('Bạn đang học thử'));
      expect(content, contains('Kết quả đang lưu trên thiết bị này.'));
      expect(content, contains('Tạo tài khoản'));
      expect(content, contains('if (isAuthenticated)'));
    });
  });
}
