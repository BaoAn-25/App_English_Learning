# Curriculum JSON schema (Tiếng Anh 12 Global Success)

Nguồn cấu trúc: `assets/data/textbook.json` (mục lục, trang in). Trang in `N` tương ứng asset `assets/textbook/page-{N+2:03}.webp`
và OCR `output/textbook-ocr/page-{N+2:03}.json` (OCR chỉ hỗ trợ — luôn đối chiếu ảnh trang).

Mỗi Unit/Review là một file: `assets/data/curriculum/unit_01.json` … `unit_10.json`, `review_1.json` … `review_4.json`.

## Nguyên tắc nội dung

- `textbook` = nguyên văn SGK (đề bài, đoạn văn, hội thoại, phương án). Không sửa câu chữ, không tự sáng tác.
- `app_compiled` = bản dịch / lời giải / đáp án do ứng dụng biên soạn. KHÔNG gọi là đáp án chính thức
  (`officialAnswerKeyAvailable=false`).
- Không có fallback chung. Nếu chưa số hóa được hoạt động thì vẫn liệt kê activity với `status: "not_digitized"`
  và `statusNote` nói rõ thiếu gì (vd. cần ảnh, cần audio).
- Hoạt động phụ thuộc audio (listen / listen and repeat / listening task): `media.audioRequired=true`,
  `media.audioAsset=null`, `media.audioStatus="missing"`. Transcript (nếu SGK in) vẫn có thể đưa vào `content`.
- Hoạt động dựa vào hình: nếu không thể thay hình bằng mô tả tương đương → `status: "needs_image"`; nếu có thể
  dùng crop trang sách thì ghi `content.pageImageRef` = số trang in.
- Không đếm trùng: Pronunciation là `subskill` trong section `language`.

## Cấu trúc

```jsonc
{
  "schemaVersion": 1,
  "bookVersion": "global-success-12-2026-v1",
  "unitId": "gs12_u01",              // khớp textbook.json
  "kind": "unit",                     // unit | review
  "unitNumber": 1,                    // review: 1..4
  "title": "Life stories we admire",
  "printedPages": [8, 19],
  "contentVersion": 1,
  "sections": [
    {
      "sectionId": "gs12_u01_getting_started",
      "type": "getting_started",      // getting_started | language | reading | speaking | listening | writing |
                                      // communication_culture | looking_back | project | review_language | review_skills
      "title": "Getting Started",
      "subtitle": "The diary of Dang Thuy Tram",   // tiêu đề in trong sách nếu có
      "printedPage": 8,
      "trialLessonId": null,          // section reading: id bài đọc tương tác đã có trong lib/data/trial_lesson_repository.dart
                                      // (vd. "trial_unit1_reading"); khi đó chỉ liệt kê các activity KHÁC ngoài bài đó
      "activities": [ /* Activity */ ]
    }
  ]
}
```

### Activity

```jsonc
{
  "activityId": "gs12_u01_gs_a2",     // ổn định: {unitId}_{sectionAbbr}_a{number}[_{subskill}]
  "number": "2",                      // số hoạt động in trong sách
  "subskill": null,                   // language: pronunciation | vocabulary | grammar; communication_culture: everyday_english | culture_clil
  "printedPage": 8,
  "instruction": "Read the conversation again and decide whether the following statements are true (T) or false (F).", // nguyên văn
  "instructionVi": "Đọc lại hội thoại và cho biết các câu sau đúng (T) hay sai (F).",                                  // app_compiled
  "interaction": "true_false",
  "content": { /* tùy interaction, xem dưới */ },
  "items": [ /* Item */ ],
  "rubric": null,                     // writing / speaking / project
  "media": { "audioRequired": false, "audioAsset": null, "audioStatus": "not_needed" }, // not_needed | missing | available
  "answerSource": "app_compiled",     // app_compiled | none (mở / tự do) | official (chỉ khi có tài liệu)
  "status": "ready",                  // ready | needs_audio | needs_image | not_digitized
  "statusNote": null,
  "trialAllowed": false
}
```

### interaction và content

| interaction | content | items |
|---|---|---|
| `dialogue` / `passage` (đọc/nghe-đọc) | `lines: [{speaker, text, translationVi?}]` hoặc `paragraphs: [{label, text, translationVi?}]` | `[]` |
| `single_choice` | `passageRef?` (activityId chứa đoạn văn), `contextText?` | `prompt`, `options: [{id:"a",text}]`, `answer: ["b"]` |
| `true_false` | như trên | `prompt`, `options` = `[{id:"T",text:"True"},{id:"F",text:"False"}]`, `answer` |
| `matching` | `left: [{id,text}]`, `right: [{id,text}]` | mỗi item: `prompt` = id bên trái, `answer: [id bên phải]` |
| `gap_fill` | `wordBank?: [..]`, `contextText?` | `prompt` chứa `___` cho mỗi chỗ trống, `answer: ["đáp án 1", ...]`, `acceptable?: [[...]]` |
| `ordering` | `segments: [{id,text}]` | 1 item, `answer: [id theo thứ tự đúng]` |
| `short_answer` | `contextText?` | `prompt`, `answer: [đáp án mẫu]` (chấm mềm: so khớp chuẩn hóa; nếu mở → `answerSource: none`) |
| `pronunciation` (listen & repeat / mark stress…) | `words?: [...]`, `sentences?: [...]`, `focus` (vd. "/eɪ/ vs /əʊ/") | tùy (có thể `[]`) |
| `speaking` | `task`, `prompts: [..]`, `usefulExpressions?: [..]`, `modelText?` | `[]`, rubric bắt buộc |
| `writing` | `task`, `wordLimit: {min,max}`, `outline?: [..]`, `modelText?` (chỉ khi SGK in) | `[]`, rubric bắt buộc |
| `project` | `task`, `steps: [..]`, `product` | `[]`, rubric |
| `listening_task` | `transcript?` (chỉ khi SGK in), các dạng câu hỏi như `single_choice`/`true_false`/`gap_fill` qua `subInteraction` | như dạng con |

### Item

```jsonc
{
  "itemId": "gs12_u01_gs_a2_1",
  "prompt": "Dang Thuy Tram was born in Ha Noi.",
  "options": [{"id": "T", "text": "True"}, {"id": "F", "text": "False"}],
  "answer": ["F"],
  "acceptable": null,
  "explanationVi": "Hội thoại: 'She was born in Hue in 1942.'",   // app_compiled
  "evidence": "She was born in Hue in 1942."                      // trích nguyên văn SGK làm căn cứ (nếu có)
}
```

### rubric (speaking / writing / project)

```jsonc
{ "criteria": [ {"id": "content", "labelVi": "Nội dung đủ ý theo đề", "descriptionVi": "..."} ], "source": "app_compiled" }
```

## Trạng thái

- `ready`: đủ đề, nội dung, đáp án/rubric để làm trong app.
- `needs_audio`: cần audio SGK chưa tích hợp (vẫn hiển thị đề/transcript nếu có, không giả lập player).
- `needs_image`: cần hình SGK; app hiển thị nút xem trang gốc.
- `not_digitized`: chưa số hóa — app phải hiển thị "Chưa số hóa", không chấm điểm.
