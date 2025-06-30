document.getElementById('copyButton').addEventListener('click', function() {
    // ページの内容を取得
    var pageContent = document.getElementById('1page').innerText;

    // 一時的なテキストエリアを作成
    var tempTextArea = document.createElement('textarea');
    tempTextArea.value = pageContent;
    document.body.appendChild(tempTextArea);

    // テキストエリアの内容を選択
    tempTextArea.select();

    // 選択した内容をクリップボードにコピー
    document.execCommand('copy');

    // 一時的なテキストエリアを削除
    document.body.removeChild(tempTextArea);

    // ユーザーにコピーが完了したことを通知
    alert('コンテンツがクリップボードにコピーされました');
});
