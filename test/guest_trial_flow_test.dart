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
import 'package:thpt_english/ui/auth/auth_controller.dart';
import 'package:thpt_english/ui/home/home_controller.dart';

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
    // Dọn dẹp triggers nếu có sót từ test trước
    await database.execute('DROP TRIGGER IF EXISTS fail_transfer');

    // Dọn dẹp dữ liệu trước mỗi test case để đảm bảo tính độc lập
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

    // Đặt lại trạng thái AuthController về khách
    AuthController.instance.logout();

    // Thêm các câu hỏi mẫu thực tế
    await repository.insertQuestions([
      const Question(
        id: 'q_guest_1',
        grade: 12,
        type: 'grammar',
        stem: 'If I had studied harder, I _____ the exam.',
        options: ['would pass', 'would have passed', 'will pass', 'pass'],
        correctIndex: 1,
        explanation: 'Câu điều kiện loại 3: If + had PII, would have PII.',
        difficulty: 2,
      ),
      const Question(
        id: 'q_guest_2',
        grade: 12,
        type: 'grammar',
        stem: 'She asked me where I _____ from.',
        options: ['come', 'came', 'coming', 'have come'],
        correctIndex: 1,
        explanation: 'Câu tường thuật lùi thì ở quá khứ: come -> came.',
        difficulty: 1,
      ),
    ]);
  });

  // Helper hàm tạo lượt làm bài 2 câu hợp lệ (q1 đúng, q2 sai)
  Future<void> savePracticeAttempt({
    required String ownerId,
    int score = 1,
    int durationSec = 45,
    int xp = 10,
  }) async {
    final isQ1Correct = score >= 1;
    final isQ2Correct = score >= 2;

    final wrongEntries = <WrongBookEntry>[];
    if (!isQ1Correct) {
      wrongEntries.add(const WrongBookEntry(
        questionId: 'q_guest_1',
        wrongCount: 1,
        lastWrongAt: 100045,
        nextReviewAt: 186445,
      ));
    }
    if (!isQ2Correct) {
      wrongEntries.add(const WrongBookEntry(
        questionId: 'q_guest_2',
        wrongCount: 1,
        lastWrongAt: 100045,
        nextReviewAt: 186445,
      ));
    }

    await repository.savePracticeResult(
      attempt: Attempt(
        mode: 'practice',
        type: 'grammar',
        startedAt: 100000,
        durationSec: durationSec,
        score: score,
        total: 2,
      ),
      buildAnswers: (attemptId) => [
        AttemptAnswer(
          attemptId: attemptId,
          questionId: 'q_guest_1',
          chosenIndex: isQ1Correct ? 1 : 0,
          isCorrect: isQ1Correct,
        ),
        AttemptAnswer(
          attemptId: attemptId,
          questionId: 'q_guest_2',
          chosenIndex: isQ2Correct ? 1 : 0,
          isCorrect: isQ2Correct,
        ),
      ],
      wrongEntries: wrongEntries,
      dailyStat: DailyStat(
        date: '2026-10-31',
        xp: xp,
        questionsDone: 2,
        correct: score,
        minutes: 1,
      ),
      ownerId: ownerId,
    );
  }

  // 1. Khách mở app không được tự tạo tài khoản đăng ký
  test('1. Khách mở app là phiên khách cục bộ, không tự tạo tài khoản server hay email giả', () async {
    final authController = AuthController.instance;

    expect(authController.isAuthenticated, isFalse);
    expect(authController.user.isGuest, isTrue);
    expect(authController.user.email, isEmpty);

    // Phiên khách có định danh cục bộ
    final guestId = await repository.getOrCreateGuestSessionId();
    expect(guestId.startsWith('guest_'), isTrue);
    expect(guestId.contains('@'), isFalse);
  });

  // 2. Làm bài thử có kết quả đúng theo lựa chọn thực tế
  test('2. Khách làm bài thử ghi nhận kết quả và câu trả lời thực tế', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    await savePracticeAttempt(ownerId: guestId, score: 1);

    // Kiểm tra kết quả gắn đúng phiên khách
    final attempts = await repository.getAllAttempts(ownerId: guestId);
    expect(attempts.length, 1);
    expect(attempts.first.score, 1);
    expect(attempts.first.total, 2);

    final answers = await repository.getAttemptAnswers(attempts.first.id!);
    expect(answers.length, 2);
    expect(answers.firstWhere((a) => a.questionId == 'q_guest_1').isCorrect, isTrue);
    expect(answers.firstWhere((a) => a.questionId == 'q_guest_2').isCorrect, isFalse);

    final wrongBook = await repository.getAllWrongBookEntries(ownerId: guestId);
    expect(wrongBook.length, 1);
    expect(wrongBook.first.questionId, 'q_guest_2');
  });

  // 3. Khách xem được kết quả trước khi đăng ký
  test('3. Khách xem được giải thích, kết quả và có thể đóng lời mời đăng ký', () async {
    final authController = AuthController.instance;
    expect(authController.hasDismissedGuestPrompt, isFalse);

    // Lấy câu hỏi để kiểm tra giải thích thật
    final questions = await repository.getQuestionsByIds(['q_guest_1', 'q_guest_2']);
    expect(questions.first.explanation.isNotEmpty, isTrue);
    expect(questions.first.explanation, contains('Câu điều kiện loại 3'));

    // Đóng lời mời đăng ký
    authController.dismissGuestPrompt();
    expect(authController.hasDismissedGuestPrompt, isTrue);
  });

  // 4. Đóng/mở app giữ được dữ liệu học thử
  test('4. Dữ liệu học thử và session tồn tại sau khi đóng/mở app (tái khởi động repository)', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    final session = LearningSession(
      ownerId: guestId,
      lessonId: 'grammar',
      lessonTitle: 'Luyện tập Ngữ pháp',
      currentQuestionIndex: 1,
      totalQuestions: 2,
      questionIds: const ['q_guest_1', 'q_guest_2'],
      selectedAnswers: const [1, null],
      status: 'in_progress',
    );
    await repository.saveLearningSession(session);

    // Giả lập đóng và mở lại app: tạo instance AppRepository mới
    final newRepoInstance = AppRepository();
    final restoredGuestId = await newRepoInstance.getOrCreateGuestSessionId();
    expect(restoredGuestId, equals(guestId));

    final restoredSession = await newRepoInstance.getLearningSession(restoredGuestId);
    expect(restoredSession, isNotNull);
    expect(restoredSession!.lessonTitle, 'Luyện tập Ngữ pháp');
    expect(restoredSession.currentQuestionIndex, 1);
    expect(restoredSession.selectedAnswers[0], 1);
  });

  // 5. Hủy hoặc thất bại khi đăng ký không mất bài đã học
  test('5. Đăng ký thất bại hoặc người dùng hủy bỏ không làm mất dữ liệu học thử', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    await savePracticeAttempt(ownerId: guestId, score: 2, xp: 20);

    final authController = AuthController.instance;

    // Cố gắng đăng ký khi hệ thống xác thực thật chưa sẵn sàng -> trả về false và thông báo rõ ràng
    final success = await authController.register(
      name: 'Hoc Vien Test',
      email: 'test@example.com',
      password: 'password123',
    );
    expect(success, isFalse);
    expect(authController.errorMessage, contains('chưa sẵn sàng'));

    // Kiểm tra dữ liệu phiên khách vẫn hoàn toàn nguyên vẹn
    final attempts = await repository.getAllAttempts(ownerId: guestId);
    expect(attempts.length, 1);
    expect(attempts.first.score, 2);
  });

  // 6. Khi có xác thực thật, đăng ký mới giữ đúng dữ liệu khách
  test('6. Đăng ký mới thành công chuyển quyền sở hữu toàn bộ dữ liệu khách vào tài khoản mới', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    await savePracticeAttempt(ownerId: guestId, score: 1);

    // Lưu session dở của khách
    await repository.saveLearningSession(LearningSession(
      ownerId: guestId,
      lessonId: 'grammar',
      lessonTitle: 'Luyện tập Ngữ pháp',
      currentQuestionIndex: 1,
      totalQuestions: 2,
      questionIds: const ['q_guest_1', 'q_guest_2'],
      selectedAnswers: const [1, null],
    ));

    final authController = AuthController.instance;

    // Giả lập xác thực thật thành công trả về User ID hợp lệ
    const newUserId = 'auth_user_real_9999';
    await authController.transferGuestDataAfterAuth(
      targetUserId: newUserId,
      displayName: 'Nguyen Van A',
      email: 'nguyenvana@gmail.com',
    );

    expect(authController.isAuthenticated, isTrue);
    expect(authController.user.id, newUserId);

    // Kiểm tra dữ liệu đã gắn vào tài khoản mới
    final userAttempts = await repository.getAllAttempts(ownerId: newUserId);
    expect(userAttempts.length, 1);
    expect(userAttempts.first.score, 1);

    final userWrongBook = await repository.getAllWrongBookEntries(ownerId: newUserId);
    expect(userWrongBook.length, 1);
    expect(userWrongBook.first.questionId, 'q_guest_2');

    final userSession = await repository.getLearningSession(newUserId);
    expect(userSession, isNotNull);
    expect(userSession!.lessonId, 'grammar');
  });

  // 7. Chạy lại thao tác chuyển không nhân đôi kết quả hoặc XP (Idempotency)
  test('7. Chạy lại thao tác chuyển dữ liệu không nhân đôi kết quả hoặc XP', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    await savePracticeAttempt(ownerId: guestId, score: 2, xp: 20);

    const targetUserId = 'target_user_888';

    // Chuyển lần 1
    await repository.transferGuestData(fromGuestId: guestId, toUserId: targetUserId);
    final attemptsAfterFirst = await repository.getAllAttempts(ownerId: targetUserId);
    expect(attemptsAfterFirst.length, 1);

    // Chuyển lại lần 2
    await repository.transferGuestData(fromGuestId: guestId, toUserId: targetUserId);
    final attemptsAfterSecond = await repository.getAllAttempts(ownerId: targetUserId);
    expect(attemptsAfterSecond.length, 1); // Không bị nhân đôi thành 2
  });

  // 8. Chuyển thất bại giữa chừng có thể phục hồi (rollback), không mất dữ liệu
  test('8. Rollback khi lỗi chuyển dữ liệu, giữ nguyên dữ liệu phiên khách', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    await savePracticeAttempt(ownerId: guestId, score: 2, xp: 20);

    // Tạo trigger gây lỗi khi update data_ownership
    await database.execute(
      "CREATE TEMP TRIGGER fail_transfer BEFORE UPDATE ON data_ownership BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
    );

    // Thao tác chuyển gặp lỗi phải ném DatabaseException
    await expectLater(
      repository.transferGuestData(fromGuestId: guestId, toUserId: 'user_fail_test'),
      throwsA(isA<DatabaseException>()),
    );

    // Gỡ trigger
    await database.execute('DROP TRIGGER fail_transfer');

    // Dữ liệu khách vẫn còn nguyên vẹn, không bị mất
    final guestAttempts = await repository.getAllAttempts(ownerId: guestId);
    expect(guestAttempts.length, 1);
    expect(guestAttempts.first.score, 2);
  });

  // 9. Đăng nhập tài khoản cũ không tự ghi đè lịch sử
  test('9. Đăng nhập tài khoản cũ bảo vệ lịch sử đã có, không tự ý ghi đè', () async {
    const existingUserId = 'existing_user_old_111';

    // Tài khoản cũ đã có lịch sử làm bài (score: 2)
    await savePracticeAttempt(ownerId: existingUserId, score: 2, xp: 20);

    // Khách học thử tạo attempt mới (score: 1)
    final guestId = await repository.getOrCreateGuestSessionId();
    await savePracticeAttempt(ownerId: guestId, score: 1, xp: 10);

    final authController = AuthController.instance;

    // Đăng nhập tài khoản cũ không gộp (mergeGuestData = false)
    const existingProfile = UserProfile(
      id: existingUserId,
      email: 'old@test.com',
      displayName: 'Old Student',
      isLoggedIn: true,
      authProvider: 'email',
    );
    await authController.signInExistingAccount(existingUser: existingProfile, mergeGuestData: false);

    // Lịch sử của tài khoản cũ giữ nguyên vẹn
    final oldAttempts = await repository.getAllAttempts(ownerId: existingUserId);
    expect(oldAttempts.length, 1);
    expect(oldAttempts.first.score, 2);

    // Dữ liệu khách vẫn lưu riêng trên máy
    final guestAttempts = await repository.getAllAttempts(ownerId: guestId);
    expect(guestAttempts.length, 1);
    expect(guestAttempts.first.score, 1);
  });

  // 10. Đăng xuất không làm lộ dữ liệu tài khoản cho khách
  test('10. Đăng xuất reset session khách, không để lộ dữ liệu tài khoản cho phiên khách mới', () async {
    const userId = 'secret_user_777';

    await savePracticeAttempt(ownerId: userId, score: 2, xp: 20);

    final authController = AuthController.instance;
    await authController.signInExistingAccount(
      existingUser: const UserProfile(
        id: userId,
        email: 'secret@user.com',
        displayName: 'Secret User',
        isLoggedIn: true,
        authProvider: 'email',
      ),
    );

    expect(authController.isAuthenticated, isTrue);

    // Đăng xuất
    authController.logout();

    expect(authController.isAuthenticated, isFalse);
    expect(authController.user.isGuest, isTrue);

    // Lấy ID phiên khách mới sau đăng xuất
    final newGuestId = await repository.getOrCreateGuestSessionId();
    expect(newGuestId, isNot(equals(userId)));

    // Phiên khách mới không nhìn thấy dữ liệu của tài khoản vừa đăng xuất
    final leakedAttempts = await repository.getAllAttempts(ownerId: newGuestId);
    expect(leakedAttempts, isEmpty);
  });

  // 11. Lưu/chuyển từ đã ôn không đặt lại lịch ôn (SRS)
  test('11. Chuyển dữ liệu khách sang tài khoản mới bảo toàn lịch ôn SRS nguyên vẹn', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    const srsWord = WordProgress(
      wordId: 'word_thpt_001',
      reviewCount: 3,
      streak: 2,
      nextReviewAt: 1850000000,
      lastReviewedAt: 1750000000,
    );

    await repository.upsertWordProgress(srsWord, ownerId: guestId);

    // Chuyển sang tài khoản mới
    const newUserId = 'srs_user_123';
    await repository.transferGuestData(fromGuestId: guestId, toUserId: newUserId);

    final userWords = await repository.getAllWordProgress(ownerId: newUserId);
    expect(userWords.length, 1);
    final transferred = userWords.first;
    expect(transferred.wordId, 'word_thpt_001');
    expect(transferred.reviewCount, 3);
    expect(transferred.streak, 2);
    expect(transferred.nextReviewAt, 1850000000);
    expect(transferred.lastReviewedAt, 1750000000);
  });

  // 12. Tiếp tục học mở đúng bài, không mở một bài mặc định
  test('12. Tiếp tục học đọc đúng bài học dở từ LearningSession, không mở Reading Unit 3', () async {
    final guestId = await repository.getOrCreateGuestSessionId();

    final ongoingSession = LearningSession(
      ownerId: guestId,
      lessonId: 'pronunciation_stress',
      lessonTitle: 'Luyện tập Ngữ âm - Trọng âm',
      currentQuestionIndex: 3,
      totalQuestions: 10,
      questionIds: const ['q_guest_1', 'q_guest_2'],
      selectedAnswers: const [1, 0],
      status: 'in_progress',
    );

    await repository.saveLearningSession(ongoingSession);

    final homeController = HomeController(repo: repository);
    await homeController.loadHomeData(guestId);

    expect(homeController.learningSession, isNotNull);
    expect(homeController.learningSession!.lessonId, 'pronunciation_stress');
    expect(homeController.learningSession!.lessonTitle, 'Luyện tập Ngữ âm - Trọng âm');
    expect(homeController.learningSession!.currentQuestionIndex, 3);
    expect(homeController.lastStudiedUnitTitle, 'Luyện tập Ngữ âm - Trọng âm');
    expect(homeController.lastStudiedUnitTitle, isNot(contains('Reading Unit 3')));
  });

  // 13. Dữ liệu cũ chưa rõ chủ sở hữu không bị tự gán cho tài khoản mới
  test('13. Dữ liệu cũ unowned (legacy) được giữ nguyên, không bị gán vào tài khoản mới', () async {
    // Chèn trực tiếp bản ghi attempt legacy vào database (không ghi nhận trong data_ownership)
    final legacyAttemptId = await database.insert('attempts', {
      'mode': 'practice',
      'type': 'vocabulary',
      'startedAt': 500,
      'durationSec': 25,
      'score': 2,
      'total': 2,
    });

    // Khách làm bài mới (có ghi nhận data_ownership)
    final guestId = await repository.getOrCreateGuestSessionId();
    await savePracticeAttempt(ownerId: guestId, score: 1);

    const newUserId = 'safe_user_555';
    await repository.transferGuestData(fromGuestId: guestId, toUserId: newUserId);

    // Kiểm tra: Tài khoản mới chỉ nhận đúng attempt của phiên khách
    final newUserAttempts = await repository.getAllAttempts(ownerId: newUserId);
    expect(newUserAttempts.length, 1);
    expect(newUserAttempts.first.type, 'grammar');

    // Attempt legacy vẫn còn nguyên trong DB nhưng không thuộc sở hữu của newUser
    final allDbAttempts = await repository.getAllAttempts();
    expect(allDbAttempts.any((a) => a.id == legacyAttemptId), isTrue);

    final ownedKeys = await repository.getEntityKeysByOwner(newUserId, 'attempt');
    expect(ownedKeys.contains('$legacyAttemptId'), isFalse);
  });
}
