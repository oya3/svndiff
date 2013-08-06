機能：
SVN で管理されたソース差分を生成する

Usage: svndiff [options] <svn repo> <svn address> <output path>
  options : -u (svn user): user.
          : -p (svn password): password.
          : -r (start:end) : revsion number.
          : -report (fileNmae) : output add/del/mod report.
          : -d (path) : output delete path.
          : -dbg : debug mode.

仕様：
指定された svn address の開始、終了（最新）リビジョンの差分を取得する。
オプションで開始、終了リビジョンを指定することも可能。

動作確認：
windows 7(32,64)環境のみ

同梱内容：
svndiff.pl
