import 'package:flutter/material.dart';
import '../../data/textbook_repository.dart';
import '../theme/app_tokens.dart';
import '../theme/components/app_button.dart';
import '../trial/interactive_reading_text.dart';
import 'textbook_screen.dart';

/// Màn hình học tương tác phần Getting Started chuẩn SGK Tiếng Anh 12.
/// 
/// Bao gồm:
/// - Bài hội thoại mở đầu số hóa với từng lượt lời rõ ràng.
/// - Tương tác chạm từ tra nghĩa, dịch câu thoại trực tiếp qua InteractiveReadingText.
/// - Hoạt động đọc hiểu / trắc nghiệm True-False chuẩn SGK Activity 2 có chấm điểm ngay.
/// - Nút xem trang in SGK gốc để đối chiếu khi cần.
class UnitGettingStartedScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final int startPage;

  const UnitGettingStartedScreen({
    super.key,
    required this.unitNumber,
    required this.unitTitle,
    required this.startPage,
  });

  @override
  State<UnitGettingStartedScreen> createState() => _UnitGettingStartedScreenState();
}

class _UnitGettingStartedScreenState extends State<UnitGettingStartedScreen> {
  int _currentTab = 0; // 0: Hội thoại mở đầu, 1: Bài tập đọc hiểu SGK
  late final List<Map<String, String>> _dialogue;
  late final String _topicTitle;
  late final List<Map<String, dynamic>> _quizQuestions;
  late List<int?> _userAnswers;
  late List<bool> _checkedAnswers;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadUnitGettingStartedData();
    _userAnswers = List<int?>.filled(_quizQuestions.length, null);
    _checkedAnswers = List<bool>.filled(_quizQuestions.length, false);
  }

  void _loadUnitGettingStartedData() {
    switch (widget.unitNumber) {
      case 1:
        _topicTitle = 'The diary of Dang Thuy Tram';
        _dialogue = [
          {
            'speaker': 'Mark',
            'text': 'Hi, Nam. Your book must be very interesting. What are you reading?',
            'translation': 'Chào Nam. Cuốn sách của bạn có vẻ rất thú vị. Bạn đang đọc gì thế?',
          },
          {
            'speaker': 'Nam',
            'text': "I'm reading a really good book in English called Last Night I Dreamed of Peace: The Diary of Dang Thuy Tram.",
            'translation': 'Mình đang đọc một cuốn sách tiếng Anh rất hay tên là Đêm qua tôi mơ thấy hòa bình: Nhật ký Đặng Thùy Trâm.',
          },
          {
            'speaker': 'Mark',
            'text': 'Dang Thuy Tram? Who is she?',
            'translation': 'Đặng Thùy Trâm à? Cô ấy là ai vậy?',
          },
          {
            'speaker': 'Nam',
            'text': 'She was born in Hue in 1942. She studied medicine in Ha Noi, and volunteered to join the army at the age of 24, working as a surgeon during the resistance war against the US.',
            'translation': 'Cô ấy sinh năm 1942 tại Huế. Cô học ngành y tại Hà Nội, và tình nguyện gia nhập quân ngũ năm 24 tuổi, làm bác sĩ phẫu thuật trong kháng chiến chống Mỹ.',
          },
          {
            'speaker': 'Mark',
            'text': "That's when she started her diary, isn't it?",
            'translation': 'Đó là thời điểm cô ấy bắt đầu viết nhật ký phải không?',
          },
          {
            'speaker': 'Nam',
            'text': 'Yes. She wrote her diary while she was working in a field hospital in Quang Ngai Province. The diary contains personal accounts of her experiences during the war, and shows her love for her family and country.',
            'translation': 'Đúng vậy. Cô viết nhật ký khi đang công tác tại bệnh xá ở Quảng Ngãi. Nhật ký ghi lại những trải nghiệm chân thực trong chiến tranh, thể hiện tình yêu gia đình và tổ quốc.',
          },
          {
            'speaker': 'Mark',
            'text': 'Wow! It sounds interesting. Is she still alive?',
            'translation': 'Thật xúc động. Hiện giờ cô ấy còn sống không?',
          },
          {
            'speaker': 'Nam',
            'text': 'Unfortunately, she was killed by the enemy while she was doing her duty in the jungle in Quang Ngai Province. She was only 27 then.',
            'translation': 'Đáng tiếc là cô đã anh dũng hy sinh khi đang làm nhiệm vụ tại cánh rừng Quảng Ngãi. Khi đó cô mới chỉ 27 tuổi.',
          },
          {
            'speaker': 'Mark',
            'text': 'So young! What a brave woman! Did she write in English?',
            'translation': 'Còn quá trẻ! Thật là một người phụ nữ dũng cảm! Cô ấy viết bằng tiếng Anh à?',
          },
          {
            'speaker': 'Nam',
            'text': 'No, she wrote in Vietnamese. Her diary was translated into English by Andrew X. Pham, a Vietnamese-American writer.',
            'translation': 'Không, cô viết bằng tiếng Việt. Nhật ký được dịch sang tiếng Anh bởi Andrew X. Phạm, một nhà văn người Mỹ gốc Việt.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Dang Thuy Tram was born in Ha Noi.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Trong bài hội thoại, Nam nói: "She was born in Hue in 1942. She studied medicine in Ha Noi."',
          },
          {
            'statement': '2. She volunteered to join the army as a surgeon at the age of 24.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Nam nêu rõ: "...volunteered to join the army at the age of 24, working as a surgeon during the resistance war against the US."',
          },
          {
            'statement': '3. She wrote her diary originally in English.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Nam trả lời: "No, she wrote in Vietnamese. Her diary was translated into English by Andrew X. Pham."',
          },
          {
            'statement': '4. She was killed when she was only 27 years old.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Nam chia sẻ: "She was only 27 then."',
          },
        ];
        break;

      case 2:
        _topicTitle = 'A cultural exchange event';
        _dialogue = [
          {
            'speaker': 'Elena',
            'text': 'Hi, Phong. Are you preparing for our school multicultural festival this weekend?',
            'translation': 'Chào Phong. Bạn đang chuẩn bị cho lễ hội đa văn hóa của trường cuối tuần này à?',
          },
          {
            'speaker': 'Phong',
            'text': 'Yes, Elena! Our class is setting up a stall with traditional Vietnamese delicacies and bamboo dancing.',
            'translation': 'Đúng vậy Elena! Lớp mình đang dựng gian hàng với các món ăn truyền thống Việt Nam và múa sạp.',
          },
          {
            'speaker': 'Elena',
            'text': 'That sounds wonderful. Experiencing different customs helps us appreciate global diversity.',
            'translation': 'Tuyệt vời quá. Trải nghiệm các phong tục khác nhau giúp chúng ta thấu hiểu và trân trọng sự đa dạng toàn cầu.',
          },
          {
            'speaker': 'Phong',
            'text': 'Exactly. Cultural exchanges make our community more united and open-minded.',
            'translation': 'Chính xác. Giao lưu văn hóa giúp cộng đồng chúng ta thêm đoàn kết và cởi mở hơn.',
          },
        ];
        _quizQuestions = [
          {
            'statement': "1. Phong's class is preparing traditional Vietnamese food and bamboo dancing.",
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Phong nói lớp bạn ấy chuẩn bị "traditional Vietnamese delicacies and bamboo dancing".',
          },
          {
            'statement': '2. Elena believes cultural exchange makes people less interested in diversity.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Elena nhấn mạnh: "helps us appreciate global diversity".',
          },
        ];
        break;

      case 3:
        _topicTitle = 'Green Classroom Competition';
        _dialogue = [
          {
            'speaker': 'Nam',
            'text': 'Hey guys, look at this notice! Our school is holding a Green Classroom Competition. The greenest classroom will win an ecotour!',
            'translation': 'Các bạn ơi, hãy nhìn thông báo này! Trường mình đang tổ chức Cuộc thi Lớp học Xanh. Lớp xanh nhất sẽ giành được một chuyến du lịch sinh thái!',
          },
          {
            'speaker': 'Mark',
            'text': 'How exciting! But how will the classrooms be judged?',
            'translation': 'Thật hào hứng! Nhưng các lớp học sẽ được chấm điểm như thế nào?',
          },
          {
            'speaker': 'Nam',
            'text': 'It says here that classrooms will be judged on raising environmental awareness, reducing carbon footprints, and using resources efficiently.',
            'translation': 'Ở đây nói rằng các lớp sẽ được đánh giá dựa trên: nâng cao ý thức môi trường, giảm dấu chân carbon và sử dụng tài nguyên hiệu quả.',
          },
          {
            'speaker': 'Mai',
            'text': 'I guess we should start by cleaning up our classroom more frequently and having more plants in it.',
            'translation': 'Mình đoán chúng ta nên bắt đầu bằng việc dọn dẹp lớp học thường xuyên hơn và trồng thêm nhiều cây xanh trong lớp.',
          },
          {
            'speaker': 'Mark',
            'text': 'Many of our classmates buy plastic water bottles every day and throw them away after a single use. Plastic takes hundreds of years to decompose!',
            'translation': 'Nhiều bạn cùng lớp mua chai nước nhựa mỗi ngày rồi vứt đi sau một lần dùng. Nhựa mất hàng trăm năm mới phân hủy được!',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. The winner of the Green Classroom Competition will receive an ecotour.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Nam nói: "The greenest classroom will win an ecotour!"',
          },
          {
            'statement': '2. Classrooms are judged solely on the number of plants they grow.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Các lớp được đánh giá theo 3 tiêu chí: nâng cao ý thức môi trường, giảm dấu chân carbon và sử dụng tài nguyên hiệu quả.',
          },
          {
            'statement': '3. Mark points out that many students throw away single-use plastic water bottles.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Mark nhận xét: "buy plastic water bottles every day and throw them away after a single use."',
          },
        ];
        break;

      case 4:
        _topicTitle = 'Urban development';
        _dialogue = [
          {
            'speaker': 'Nam',
            'text': "Hi, Mark! It's been three years since your last visit. Do you want to go for a walk? I'll show you around.",
            'translation': 'Chào Mark! Đã ba năm kể từ lần cuối bạn đến thăm. Bạn có muốn đi dạo không? Mình sẽ dẫn bạn đi tham quan một vòng.',
          },
          {
            'speaker': 'Mark',
            'text': "There used to be a rice field opposite your house, right? Now they have built several high-rise buildings!",
            'translation': 'Từng có một cánh đồng lúa đối diện nhà bạn đúng không? Giờ họ đã xây mấy tòa nhà cao tầng rồi kìa!',
          },
          {
            'speaker': 'Nam',
            'text': 'Exactly. The city is getting bigger. More and more people want to live in urban areas nowadays as part of urbanisation.',
            'translation': 'Chính xác. Thành phố đang ngày càng lớn hơn. Ngày càng nhiều người muốn sống ở khu vực đô thị như một phần của quá trình đô thị hóa.',
          },
          {
            'speaker': 'Mark',
            'text': "And look at our new electric buses! The bus is so quiet and comfortable. Getting around is becoming much more convenient.",
            'translation': 'Và hãy nhìn xe buýt điện mới này! Xe chạy êm và thoải mái thật đấy. Đi lại đang trở nên thuận tiện hơn rất nhiều.',
          },
        ];
        _quizQuestions = [
          {
            'statement': "1. Mark has visited Nam's neighbourhood frequently in the last three years.",
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Nam nói: "It\'s been three years since your last visit."',
          },
          {
            'statement': '2. The rice field opposite Nam\'s house was replaced by high-rise buildings.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Cánh đồng lúa trước đây nay đã được thay bằng các tòa nhà cao tầng.',
          },
          {
            'statement': '3. Mark felt that the new electric bus was noisy and uncomfortable.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Mark khen ngợi: "The bus is so quiet and comfortable!"',
          },
        ];
        break;

      case 5:
        _topicTitle = "Our parents' jobs";
        _dialogue = [
          {
            'speaker': 'Lan',
            'text': 'Come in, Mark. Did you find my place easily?',
            'translation': 'Mời vào Mark. Bạn tìm nhà mình có dễ không?',
          },
          {
            'speaker': 'Mark',
            'text': 'Yes, I actually met your dad in the street and he showed me the way. He said he was on his way to work.',
            'translation': 'Có chứ, mình tình cờ gặp bố bạn trên đường và chú đã chỉ đường cho mình. Chú bảo chú đang trên đường đi làm.',
          },
          {
            'speaker': 'Lan',
            'text': "That's right. My dad is a factory worker, so he works in shifts. Today he's on the night shift.",
            'translation': 'Đúng rồi. Bố mình là công nhân nhà máy nên làm việc theo ca. Hôm nay bố làm ca đêm.',
          },
          {
            'speaker': 'Mark',
            'text': "Working night shifts must be really hard. What about your mum?",
            'translation': 'Làm ca đêm chắc vất vả lắm. Còn mẹ bạn thì sao?',
          },
          {
            'speaker': 'Lan',
            'text': 'My mum works as a nurse at the local clinic. Both of them work hard to support our family.',
            'translation': 'Mẹ mình làm y tá tại trạm y tế địa phương. Cả hai bố mẹ đều làm việc chăm chỉ để lo cho gia đình.',
          },
        ];
        _quizQuestions = [
          {
            'statement': "1. Lan's father works in shifts as a factory worker.",
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Lan nói: "My dad is a factory worker, so he works in shifts."',
          },
          {
            'statement': "2. Lan's mother works in the same factory as her father.",
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Mẹ Lan làm y tá tại trạm y tế địa phương.',
          },
        ];
        break;

      case 6:
        _topicTitle = 'A visit to a high-tech centre';
        _dialogue = [
          {
            'speaker': 'Teacher',
            'text': "Hello, class. Please meet Jessica. She's a human-like robot and will be your guide today.",
            'translation': 'Chào cả lớp. Thầy xin giới thiệu Jessica. Cô ấy là robot hình người và sẽ là hướng dẫn viên của các em hôm nay.',
          },
          {
            'speaker': 'Jessica',
            'text': 'Good morning, everybody. Welcome to the New Tech Centre. Please follow me to the robot exhibition.',
            'translation': 'Chào buổi sáng mọi người. Chào mừng các bạn đến với Trung tâm Công nghệ Mới. Xin mời đi theo tôi đến khu triển lãm robot.',
          },
          {
            'speaker': 'Nam',
            'text': "Hi, Jessica. I'm so excited as I've never met a talking robot before. Can we interact with them?",
            'translation': 'Chào Jessica. Mình hào hứng quá vì chưa từng gặp robot biết nói trước đây. Chúng mình có thể tương tác với các robot không?',
          },
          {
            'speaker': 'Jessica',
            'text': 'Yes, you can! They are all powered by artificial intelligence and capable of answering your questions.',
            'translation': 'Được chứ! Tất cả đều được vận hành bởi trí tuệ nhân tạo và có khả năng trả lời các câu hỏi của các bạn.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Jessica is a human tour guide working at the tech centre.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Jessica là robot hình người (human-like robot).',
          },
          {
            'statement': '2. Visitors can interact with and ask questions to the AI robots.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Jessica xác nhận: "They are all capable of answering your questions."',
          },
        ];
        break;

      case 7:
        _topicTitle = 'Promoting a charity event';
        _dialogue = [
          {
            'speaker': 'Mark',
            'text': "Hi, Mai. What's up? You look so worried!",
            'translation': 'Chào Mai. Có chuyện gì thế? Trông bạn có vẻ lo lắng quá!',
          },
          {
            'speaker': 'Mai',
            'text': "I'm so stressed! The school charity club is planning a music show, and I'm in charge of the publicity. There hasn't been much interest so far.",
            'translation': 'Mình căng thẳng quá! Câu lạc bộ từ thiện của trường đang lên kế hoạch làm một đêm nhạc, và mình phụ trách truyền thông. Nhưng đến giờ chưa có nhiều người quan tâm.',
          },
          {
            'speaker': 'Mark',
            'text': 'Why don\'t you use social media platforms and short videos to attract students\' attention? Mass media is very powerful!',
            'translation': 'Sao bạn không dùng các nền tảng mạng xã hội và video ngắn để thu hút sự chú ý của học sinh? Truyền thông đại chúng có sức lan tỏa rất lớn đấy!',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Mai is in charge of publicity for a school music show.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Mai phụ trách quảng bá: "I\'m in charge of the publicity for the event."',
          },
          {
            'statement': '2. Mark advises Mai not to use social media because it is ineffective.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Mark khuyên Mai nên dùng mạng xã hội và video ngắn vì truyền thông có sức lan tỏa mạnh.',
          },
        ];
        break;

      case 8:
        _topicTitle = 'At a rescue centre';
        _dialogue = [
          {
            'speaker': 'Ms Smith',
            'text': 'Welcome to the Endangered Primate Rescue Centre! If you have any questions during the tour, don\'t hesitate to ask me.',
            'translation': 'Chào mừng các em đến Trung tâm Cứu hộ Linh trưởng Nguy cấp! Nếu có bất kỳ câu hỏi nào trong chuyến tham quan, đừng ngần ngại hỏi cô nhé.',
          },
          {
            'speaker': 'Mark',
            'text': "I've just seen a monkey in the enclosure. So are primates just monkeys, Ms Smith?",
            'translation': 'Em vừa thấy một chú khỉ trong chuồng. Vậy linh trưởng chỉ là loài khỉ thôi hả cô Smith?',
          },
          {
            'speaker': 'Ms Smith',
            'text': 'No, primates are a group of mammals that includes lemurs, lorises, monkeys, and apes. Many species are critically endangered.',
            'translation': 'Không đâu em, linh trưởng là nhóm thú bao gồm vượn cáo, cu li, khỉ và vượn người. Nhiều loài đang bị đe dọa tuyệt chủng nghiêm trọng.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Monkeys are the only group of animals that belong to primates.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Cô Smith giải thích linh trưởng bao gồm cả lemurs, lorises, monkeys và apes.',
          },
          {
            'statement': '2. Many primate species at the rescue centre are critically endangered.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Nhiều loài linh trưởng đang bị đe dọa tuyệt chủng ở mức nghiêm trọng.',
          },
        ];
        break;

      case 9:
        _topicTitle = 'Q&A with a career adviser';
        _dialogue = [
          {
            'speaker': 'Mr Kien',
            'text': "I hope you'll continue to keep up with the rapid changes in the job market. Have you got any questions?",
            'translation': 'Thầy hy vọng các em sẽ tiếp tục nắm bắt những thay đổi nhanh chóng của thị trường lao động. Các em có câu hỏi nào không?',
          },
          {
            'speaker': 'Nam',
            'text': 'Yes, do you think we need to have a university degree to pursue a good career?',
            'translation': 'Dạ có, thầy có nghĩ rằng chúng em bắt buộc phải có bằng đại học để theo đuổi một sự nghiệp tốt không ạ?',
          },
          {
            'speaker': 'Mr Kien',
            'text': "Well, it depends on the industry. There are many rewarding jobs that don't require a university degree, such as flight attendants, car mechanics, or skilled technicians.",
            'translation': 'Điều đó phụ thuộc vào ngành nghề. Có rất nhiều công việc đáng giá không đòi hỏi bằng đại học, chẳng hạn như tiếp viên hàng không, thợ sửa xe hơi hay kỹ thuật viên tay nghề cao.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Mr Kien says that a university degree is strictly required for every single job.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Thầy Kiên khẳng định có nhiều công việc bổ ích không bắt buộc phải có bằng đại học.',
          },
          {
            'statement': '2. Vocational careers like flight attendant or mechanic can be pursued without a degree.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Thầy Kiên lấy dẫn chứng tiếp viên hàng không và thợ máy.',
          },
        ];
        break;

      case 10:
        _topicTitle = 'Learning for life';
        _dialogue = [
          {
            'speaker': 'Mark',
            'text': 'Hello, Grandma! What are you doing on your laptop?',
            'translation': 'Cháu chào bà! Bà đang làm gì trên máy tính xách tay thế ạ?',
          },
          {
            'speaker': 'Grandma',
            'text': 'Oh hi, Mark. Can you help me increase the font size of this text? I still have trouble learning computer skills, but I want to keep learning!',
            'translation': 'Chào Mark. Cháu có thể giúp bà tăng cỡ chữ của văn bản này không? Bà vẫn gặp khó khăn khi học kỹ năng máy tính, nhưng bà muốn tiếp tục học hỏi!',
          },
          {
            'speaker': 'Mark',
            'text': "That's wonderful, Grandma! My teacher says it's never too late to learn something new. Lifelong learning keeps your mind active and happy.",
            'translation': 'Tuyệt vời quá bà ơi! Thầy giáo cháu dạy rằng không bao giờ là quá muộn để học điều mới. Học tập suốt đời giúp trí não luôn năng động và vui tươi.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Grandma believes that older people should stop learning new skills.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 1,
            'explanation': 'Sai. Bà của Mark rất tích cực học máy tính và tinh thần học tập suốt đời.',
          },
          {
            'statement': '2. Mark supports his grandma and agrees that it is never too late to learn.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Mark chia sẻ: "it\'s never too late to learn something new."',
          },
        ];
        break;

      default:
        _topicTitle = 'Review & Consolidation';
        _dialogue = [
          {
            'speaker': 'Mark',
            'text': 'Let\'s review what we have learned in this section and apply it to our practice exercises.',
            'translation': 'Chúng ta hãy cùng ôn tập lại những gì đã học trong phần này và áp dụng vào các bài luyện tập nhé.',
          },
        ];
        _quizQuestions = [
          {
            'statement': '1. Reviewing helps consolidate English knowledge for the graduation exam.',
            'options': ['True (Đúng)', 'False (Sai)'],
            'correctIndex': 0,
            'explanation': 'Đúng. Ôn tập thường xuyên giúp củng cố kiến thức thi tốt nghiệp THPT.',
          },
        ];
        break;
    }
  }

  Future<void> _openTextbookOriginal() async {
    try {
      final repo = TextbookRepository();
      final book = await repo.load();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextbookReader(
            book: book,
            initialPage: widget.startPage,
            start: widget.startPage,
            end: widget.startPage + 11,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải trang in SGK. Vui lòng thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context, _isCompleted),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Getting Started · Khởi động',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.primary),
            ),
            Text(
              'Unit ${widget.unitNumber}: ${widget.unitTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppTokens.primary),
            label: const Text(
              'Trang in SGK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.primary,
              ),
            ),
            onPressed: _openTextbookOriginal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Tab Bar (Hội thoại / Đọc hiểu SGK)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentTab = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentTab == 0 ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _currentTab == 0 ? const Color(0xFF93C5FD) : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '1. Hội thoại tương tác',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: _currentTab == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: _currentTab == 0 ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentTab = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _currentTab == 1 ? const Color(0xFFEFF6FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _currentTab == 1 ? const Color(0xFF93C5FD) : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '2. Bài tập SGK (${_quizQuestions.length} câu)',
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 13,
                            fontWeight: _currentTab == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _currentTab == 1 ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Nội dung tab
          Expanded(
            child: _currentTab == 0 ? _buildDialogueTab() : _buildQuizTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogueTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card chủ đề
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, color: AppTokens.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _topicTitle,
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Chạm từ bất kỳ để tra cứu nghĩa · Bấm "Dịch câu thoại" bên dưới để xem đối chiếu tiếng Việt.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Các lượt lời hội thoại
        ..._dialogue.map((item) {
          final speaker = item['speaker'] ?? '';
          final text = item['text'] ?? '';
          final translation = item['translation'] ?? '';
          final isMark = speaker == 'Mark' || speaker == 'Teacher';

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar nhân vật
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isMark ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                  child: Text(
                    speaker.isNotEmpty ? speaker[0] : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isMark ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Bong bóng hội thoại
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          speaker,
                          style: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isMark ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InteractiveReadingText(
                          text: text,
                          translation: translation,
                          translateButtonLabel: 'Dịch câu thoại',
                          showTranslateButton: true,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),
        AppButton(
          label: 'Làm bài tập đọc hiểu SGK (Activity 2) →',
          variant: AppButtonVariant.primary,
          height: 48,
          onPressed: () => setState(() => _currentTab = 1),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuizTab() {
    final answeredCount = _checkedAnswers.where((c) => c).length;
    final allAnswered = answeredCount == _quizQuestions.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.quiz_outlined, color: AppTokens.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity 2: Đọc hiểu hội thoại',
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Đọc lại cuộc trò chuyện và xác định câu Đúng (True) hoặc Sai (False).',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ..._quizQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final statement = q['statement'] as String;
          final options = (q['options'] as List).cast<String>();
          final correctIdx = q['correctIndex'] as int;
          final explanation = q['explanation'] as String;
          final selectedOption = _userAnswers[index];
          final isChecked = _checkedAnswers[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Options
                ...options.asMap().entries.map((optEntry) {
                  final optIdx = optEntry.key;
                  final optText = optEntry.value;
                  final isSelected = selectedOption == optIdx;

                  Color bg = Colors.white;
                  Color border = const Color(0xFFE2E8F0);
                  if (isChecked) {
                    if (optIdx == correctIdx) {
                      bg = const Color(0xFFF0FDF4);
                      border = const Color(0xFF22C55E);
                    } else if (isSelected) {
                      bg = const Color(0xFFFEF2F2);
                      border = AppTokens.errorRed;
                    }
                  } else if (isSelected) {
                    bg = const Color(0xFFEFF6FF);
                    border = AppTokens.primary;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isChecked
                          ? null
                          : () {
                              setState(() {
                                _userAnswers[index] = optIdx;
                                _checkedAnswers[index] = true;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border, width: isSelected ? 1.5 : 1.0),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? AppTokens.primary : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                optText,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13.5,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (isChecked) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedOption == correctIdx
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selectedOption == correctIdx
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: selectedOption == correctIdx
                              ? const Color(0xFF16A34A)
                              : AppTokens.errorRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            explanation,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        if (allAnswered) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Bạn đã hoàn thành phần Getting Started!',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _isCompleted = true);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Hoàn tất'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
