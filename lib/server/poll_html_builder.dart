import '../models/poll.dart';
import '../models/question.dart';

/// 클라이언트 응답 페이지(HTML)를 동적으로 생성한다.
String buildPollResponseHtml(Poll poll) {
  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="ko"><head><meta charset="UTF-8">');
  buffer.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">');
  buffer.writeln('<title>${_esc(poll.title)}</title>');
  buffer.writeln(_pageStyle());
  buffer.writeln('</head><body>');

  if (!poll.isPublished) {
    buffer.writeln('<div class="container">');
    buffer.writeln('<h1>설문이 아직 공개되지 않았습니다</h1>');
    buffer.writeln('<p>관리자가 설문을 퍼블리시하면 응답할 수 있습니다.</p>');
    buffer.writeln('</div></body></html>');
    return buffer.toString();
  }

  buffer.writeln('<div class="container">');
  buffer.writeln('<h1>${_esc(poll.title)}</h1>');
  buffer.writeln('<p class="desc">${_esc(poll.description)}</p>');
  buffer.writeln('<form id="pollForm">');

  for (final q in poll.questions) {
    buffer.writeln(_renderQuestion(q));
  }

  buffer.writeln('<button type="submit" class="submit">응답 제출</button>');
  buffer.writeln('</form>');
  buffer.writeln('<div id="doneMsg" class="success" style="display:none;">'
      '응답이 제출되었습니다. 감사합니다!</div>');
  buffer.writeln(_script(poll.id));
  buffer.writeln('</div></body></html>');
  return buffer.toString();
}

String _renderQuestion(Question q) {
  final b = StringBuffer();
  b.writeln('<div class="question">');
  b.writeln(
      '<label class="qtext">${_esc(q.text)}${q.required ? ' <span class="req">*</span>' : ''}</label>');
  if (q.type == QuestionType.radio) {
    for (var i = 0; i < q.options.length; i++) {
      final opt = q.options[i];
      b.writeln('<label class="option"><input type="radio" name="q_${q.id}" '
          'value="${_esc(opt)}" ${q.required ? 'required' : ''}> ${_esc(opt)}</label>');
    }
  } else if (q.type == QuestionType.checkbox) {
    for (var i = 0; i < q.options.length; i++) {
      final opt = q.options[i];
      b.writeln(
          '<label class="option"><input type="checkbox" name="q_${q.id}" '
          'value="${_esc(opt)}"> ${_esc(opt)}</label>');
    }
  } else {
    b.writeln(
        '<textarea name="q_${q.id}" ${q.required ? 'required' : ''}></textarea>');
  }
  b.writeln('</div>');
  return b.toString();
}

String _pageStyle() => '''
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f4f6f8; margin: 0; padding: 24px 16px; }
  .container { max-width: 600px; margin: 0 auto; background: #fff; border-radius: 12px;
    padding: 24px; box-shadow: 0 2px 10px rgba(0,0,0,0.08); }
  h1 { color: #222; font-size: 22px; margin-bottom: 4px; }
  .desc { color: #666; margin-bottom: 20px; }
  .question { margin: 18px 0; padding: 14px; border: 1px solid #e5e5e5; border-radius: 8px; }
  .qtext { display: block; font-weight: 600; margin-bottom: 10px; }
  .req { color: #e53935; }
  .option { display: block; padding: 6px 0; cursor: pointer; }
  textarea { width: 100%; min-height: 80px; padding: 8px; border-radius: 6px; border: 1px solid #ccc; font-family: inherit; }
  .submit { width: 100%; background: #2563eb; color: #fff; border: none; padding: 14px;
    border-radius: 8px; font-size: 16px; cursor: pointer; margin-top: 8px; }
  .submit:hover { background: #1d4ed8; }
  .success { text-align: center; color: #16a34a; font-size: 18px; font-weight: 600; padding: 24px 0; }
</style>
''';

String _script(String pollId) => '''
<script>
document.getElementById('pollForm').addEventListener('submit', async function(e) {
  e.preventDefault();
  const form = e.target;
  const formData = new FormData(form);
  const answers = {};
  for (const el of form.elements) {
    if (!el.name || !el.name.startsWith('q_')) continue;
    const qid = el.name.substring(2);
    if (el.type === 'checkbox') {
      if (!el.checked) continue;
      answers[qid] = answers[qid] || [];
      answers[qid].push(el.value);
    } else if (el.type === 'radio') {
      if (el.checked) answers[qid] = el.value;
    } else {
      answers[qid] = el.value;
    }
  }
  try {
    const res = await fetch('/api/polls/$pollId/responses', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ answers: answers })
    });
    if (res.ok) {
      form.style.display = 'none';
      document.getElementById('doneMsg').style.display = 'block';
    } else {
      alert('제출 중 오류가 발생했습니다.');
    }
  } catch (err) {
    alert('서버에 연결할 수 없습니다.');
  }
});
</script>
''';

String _esc(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
