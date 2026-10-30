"""Build the offline book package from publisher pages and reviewed glossary.

Page images remain the authoritative content. OCR is only a search index.
Generated quizzes are explicitly labelled adaptations, not publisher answers.
"""
import hashlib
import json
import random
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets/data'
BOOK = ROOT / 'assets/textbook'
SOURCE = ROOT / 'output/pdf/global-success-12'
VERSION = 'global-success-12-2026-v1'
TITLES = ['Life stories we admire', 'A multicultural world', 'Green living',
          'Urbanisation', 'The world of work', 'Artificial intelligence',
          'The world of mass media', 'Wildlife conservation', 'Career paths',
          'Lifelong learning']
STARTS = [8, 20, 32, 48, 60, 76, 88, 100, 116, 128]
SECTIONS = ['Getting Started', 'Language', 'Reading', 'Speaking', 'Listening',
            'Writing', 'Communication and Culture / CLIL', 'Looking Back', 'Project']
SECTION_PAGES = [[8,9,11,13,14,15,16,18,19], [20,21,23,25,26,27,28,30,31],
 [32,33,35,37,38,39,40,42,43], [48,49,52,54,54,55,56,58,59],
 [60,62,64,66,67,68,69,70,71], [76,78,80,82,82,83,84,86,87],
 [88,90,92,94,95,96,97,98,99], [100,102,104,105,106,108,108,110,111],
 [116,118,120,121,122,123,124,126,127], [128,130,132,134,135,136,136,138,139]]


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    BOOK.mkdir(parents=True, exist_ok=True)
    topics = [dict(id=f'gs12_u{i+1:02}', grade=12, title=f'Unit {i+1}: {t}', order=i+1)
              for i, t in enumerate(TITLES)]
    units = []
    for i, (title, start, sections) in enumerate(zip(TITLES, STARTS, SECTION_PAGES)):
        units.append(dict(id=topics[i]['id'], title=topics[i]['title'], start=start,
            end=start+11, kind='unit', sections=[dict(title=name, page=p)
                for name,p in zip(SECTIONS, sections)]))
    for i, start in enumerate([44,72,112,140]):
        units.append(dict(id=f'gs12_review{i+1}', title=f'Review {i+1}', start=start,
            end=start+3, kind='review', sections=[dict(title='Language',page=start),
                dict(title='Skills',page=start+2)]))
    units.extend([
        dict(id='gs12_intro',title='Bìa, mục lục và Book Map',start=-1,end=7,kind='reference',sections=[]),
        dict(id='gs12_appendix1',title='Appendix 1 · Communication strategies',start=144,end=144,kind='reference',sections=[]),
        dict(id='gs12_appendix2',title='Appendix 2 · Exam strategies',start=145,end=146,kind='reference',sections=[]),
        dict(id='gs12_glossary',title='Glossary · Từ vựng theo Unit',start=147,end=155,kind='reference',sections=[]),
        dict(id='gs12_publication',title='Thông tin xuất bản và bìa sau',start=156,end=157,kind='reference',sections=[]),
    ])
    pages=[]
    for n in range(1,160):
        src=SOURCE/f'page-{n:03}.png'
        # Lossless WebP keeps every pixel while reducing the offline package.
        from PIL import Image
        dest=BOOK/f'page-{n:03}.webp'
        if not dest.exists(): Image.open(src).save(dest, format='WEBP', lossless=True, method=4)
        ocr=json.loads((ROOT/f'output/textbook-ocr/page-{n:03}.json').read_text(encoding='utf-8-sig'))
        pages.append(dict(number=n-2, asset=f'assets/textbook/{dest.name}',
                          searchText=ocr['text'], sha256=hashlib.sha256(src.read_bytes()).hexdigest()))
    manifest=dict(version=VERSION,title='Tiếng Anh 12 · Global Success',
        source='https://taphuan.nxbgd.vn/tap-huan/doc-sach/sgk-tieng-anh-12-global-success.4879792656',
        audioAvailable=False, officialAnswerKeyAvailable=False,
        searchTextStatus='OCR; đối chiếu ảnh sách khi có sai khác',units=units,pages=pages)
    words=[]; refs={}
    raw=[]
    for line in (ROOT/'tools/textbook_glossary.tsv').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'): continue
        unit,page,en,vi=line.split('|'); raw.append((int(unit),int(page),en,vi))
    for i,(unit,page,en,vi) in enumerate(sorted(raw)):
        wid=f'gs12_u{unit:02}_w{i+1:03}'
        words.append(dict(id=wid,topicId=f'gs12_u{unit:02}',grade=12,english=en,
            ipa='',meaningVi=vi,example=''))
        refs[wid]=dict(page=page, section='Glossary', unit=unit,
            note='Nghĩa tiếng Việt được biên tập ngắn gọn theo Glossary. Xem phiên âm và từ loại trên trang sách gốc.')
    assert len({(w['topicId'],w['english']) for w in words})==len(words)
    questions=[]
    rng=random.Random(121026)
    for w in words:
        alternatives=sorted({v['meaningVi'] for v in words if v['meaningVi']!=w['meaningVi']})
        options=[w['meaningVi']]+rng.sample(alternatives,3); rng.shuffle(options)
        page=refs[w['id']]['page']
        questions.append(dict(id=w['id']+'_quiz',grade=12,type='vocab',
            stem=f'Theo Glossary của Unit {refs[w["id"]]["unit"]}, “{w["english"]}” có nghĩa là gì?',
            options=options,correctIndex=options.index(w['meaningVi']),
            explanation=f'{w["english"]}: {w["meaningVi"]}. Nguồn: Glossary, trang {page}. Câu ôn tập được biên soạn từ sách, không phải câu hỏi nguyên bản.',
            topicId=w['topicId'],passageId=None,difficulty=1))
    for name,value in [('topics',topics),('words',words),('questions',questions),
                       ('textbook',manifest),('word_sources',refs)]:
        write(DATA/f'{name}.json',value)
    print(f'Built {len(pages)} pages, {len(units)} collections, {len(words)} words, {len(questions)} quizzes.')


if __name__=='__main__': main()
