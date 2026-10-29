-- Historical v1 schema from e465e6c^, kept independent of current onCreate.
CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        grade INTEGER NOT NULL,
        title TEXT NOT NULL,
        "order" INTEGER NOT NULL
      );
CREATE TABLE words (
        id TEXT PRIMARY KEY,
        topicId TEXT NOT NULL,
        grade INTEGER NOT NULL,
        english TEXT NOT NULL,
        ipa TEXT NOT NULL,
        meaningVi TEXT NOT NULL,
        example TEXT NOT NULL
      );
CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        grade INTEGER NOT NULL,
        type TEXT NOT NULL,
        stem TEXT NOT NULL,
        options TEXT NOT NULL,
        correctIndex INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        topicId TEXT,
        passageId TEXT,
        difficulty INTEGER NOT NULL
      );
CREATE TABLE attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        type TEXT,
        startedAt INTEGER NOT NULL,
        durationSec INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL
      );
CREATE TABLE attempt_answers (
        attemptId INTEGER NOT NULL,
        questionId TEXT NOT NULL,
        chosenIndex INTEGER NOT NULL,
        isCorrect INTEGER NOT NULL,
        PRIMARY KEY (attemptId, questionId)
      );
CREATE TABLE wrong_book (
        questionId TEXT PRIMARY KEY,
        wrongCount INTEGER NOT NULL,
        lastWrongAt INTEGER NOT NULL,
        nextReviewAt INTEGER NOT NULL
      );
CREATE TABLE daily_stats (
        date TEXT PRIMARY KEY,
        xp INTEGER NOT NULL,
        questionsDone INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        minutes INTEGER NOT NULL
      );
CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
PRAGMA user_version = 1;
