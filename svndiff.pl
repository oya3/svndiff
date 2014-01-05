#<!-- -*- encoding: utf-8n -*- -->
use strict;
use warnings;
use utf8;

use Cwd;
use Encode;
use Encode::JP;

use Data::Dumper;
{
    package Data::Dumper;
	no warnings 'redefine'; # 関数再定義警告を無効
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

print "svndiff ver. 0.13.12.27.\n";
my ($argv, $gOptions) = getOptions(\@ARGV); # オプションを抜き出す
my $args = @{$argv};

if( $args != 2 ){
	print "Usage: svndiff [options] <svn address> <output path>\n";
	print "  options : -u : user.\n";
	print "          : -p : password.\n";
	print "          : -r (start:end) : revsion number.\n";
	print "          : -report (fileNmae) : output add/del/mod report.\n";
	print "          : -shortpath : short output path.\n";
	print "          : -dbg : debug mode.\n";
	print "https://github.com/oya3/svndiff\n";
    exit;
}

#$gOptions->{'dbg'} = 1;

if( !isInstallSVN() ){
	die "svn not installed.";
}

my $fileList = undef;
my $srev = '';
my $erev = '';

my $address = $argv->[0];
my $outputPath  = $argv->[1];
my $svnrepo = getRepositoryRoot($address);
print "Repository Root: $svnrepo\n";

# $gOptions->{'dbg'} = "ON"; # debug print on

# オプション指定でリビジョンが存在か確認
if( exists $gOptions->{'r_start'} ){
	# オプション指定がある
	($srev, $erev, $fileList) = getRevisionNumber($svnrepo, $address, "-r $gOptions->{'r_end'}:$gOptions->{'r_start'} --verbose" );
}
else{
	# ブランチの最初と最後のリビジョンを取得する
	($srev, $erev, $fileList) = getRevisionNumber($svnrepo, $address, "--stop-on-copy --verbose" );
}

#print "&&& filelist. &&&\n".encode('cp932', Dumper($fileList))."\n";

my $sErrorFile = svnExportFiles("$srev", $svnrepo, $address, $fileList, $outputPath); # 開始
my $eErrorFile = svnExportFiles("$erev", $svnrepo, $address, $fileList, $outputPath); # 終了

if( exists $gOptions->{'report'} ){
	exportReport( "$outputPath\/$gOptions->{'report'}", $fileList, $gOptions->{'d'});
}

## export コマンドで@PEGREVを指定することで、削除済みファイルをエクスポートできることが
## 判明したため削除リストを表示する必要はなくなった。
# putDeletedList($fileList);

print "complate.\n";
exit;

sub getRepositoryRoot
{
 	my $address = shift;
 	my $res = svnCmd("info" , "", "$address", "");
 	my $string = join '', @{$res};
	if( $string =~ /Repository Root: (.+?)$/m ){
 		return $1;
 	}
 	die "illigal svn info command. $res";
 	return 'error';
}

sub dbg_print
{
	my ($string) = @_;
	if( defined $gOptions->{'dbg'} ){
		print encode('cp932', $string);
	}
}

# 削除済みファイルリストを出力
# svn copy http://localhost/svn/repository/hoge.txt@10
# このコマンドでファイル単位で削除済みファイルを復活させれるかもしれない。
sub putDeletedList
{
	my ($fileList) = @_;
	my @deleteList = ();
	foreach my $file ( sort keys %{$fileList} ){
		if( 'D' eq $fileList->{$file} ) {
			push @deleteList, $file;
		}
	}
	if( 0 ==@deleteList ){
		return;
	}
	print encode('cp932', "deleted list.\n");
	foreach my $path (@deleteList) {
		print encode('cp932', "$path\n");
	}
	
}

sub exportReport
{
	my ($file,$fileList,$deletePath) = @_;

	print encode('cp932', "export report.[$file]\n");
	
	my $file_sjis = encode('cp932', $file);
	my %keys = ("A"=>"追加", "D"=>"削除", "M"=>"変更", "R"=>"置換");
	
	open (OUT, ">$file_sjis") or die "$!";
	foreach my $file ( sort keys %{$fileList} ){
		my $sts = $fileList->{$file};
		
		if( defined $deletePath ){
			if( $file =~ /^$deletePath(.+?)$/ ){
				$file = $1;
			}
		}
		
		print OUT encode('cp932', "$file,$keys{$sts}\n");
	}
	close OUT;
}

sub _mkdir
{
	my $path = shift;
	my @array = split /[\/\\]/, $path;
	my $paths = '';
	foreach my $dir (@array){
		if( $dir ){
			$paths = $paths."$dir";
			mkdir encode('cp932', "$paths");
		}
		$paths = $paths."\/";
	}
}

sub svnExportFiles
{
	my ($rev, $svnrepo, $address, $files, $path) = @_;
	print encode('cp932', "exporting rev\.$rev\...\n");

	my $deletePath = undef;
	if( exists $gOptions->{'shortpath'} ){ # 短縮出力パスが有効の場合
		$deletePath = $address;
		$deletePath =~ s/$svnrepo(.+)$/$1/;
	}
	
	$path = $path."\/$rev";
	my @notFoundFile = ();
	foreach my $file ( keys %{$files} ){
		if( $file !~ /\..+?$/ ){
			next; # フォルダなんで無視（T.B.D）
		}
		# "linecount_test/branches/users/oya/linecount_test/..." , remove "/branches/users/oya/linecount_test" = "linecount_test/..."
		my $outFilePath = "$path"."$file";
		if( defined $deletePath ){
			if( $file =~ /^$deletePath(.+?)$/ ){
				$outFilePath = "$path"."$1";
			}
		}
		my $dir = $outFilePath;
		$dir =~ s/^(.+)[\\\/].+$/$1/;
		_mkdir $dir;
		
		#print encode('cp932',"[$files->{$file}]001file[$file][$outFilePath]\n");
		my $res = undef;
		if( 'D' eq $files->{$file} ){
			# svn copy http://localhost/svn/repository/hoge.txt@10 のように@マーク式にすると削除済みファイルも取得できる
			$res = svnCmd("export", "--force", "\"$svnrepo"."$file\@$rev\"", "\"$outFilePath\"");
		}
		else{
			$res = svnCmd("export", "-r $rev --force", "\"$svnrepo"."$file\"", "\"$outFilePath\"");
		}
#		my $res = svnCmd("cat", "-r $rev", "\"$svnrepo"."$file\"", "> \"$outFilePath\"");
		my $resString = join '', @{$res};
		dbg_print("exp :$resString");
		if( $resString =~ /svn: E(\d+?):/ ){
			push @notFoundFile, "$svnrepo"."$file";
		}
		#print @{$res};
	}
	return \@notFoundFile;
}

sub execCmd
{
	my ($cmd) = @_;
	$cmd = encode('cp932', $cmd);
	dbg_print("cmd : $cmd\n");
#	$cmd = encode('cp932', $cmd);
	open my $rs, "$cmd 2>&1 |";
	my @rlist = <$rs>;
	my @out = ();
	foreach my $line (@rlist){
		push @out, decode('cp932', $line);
	}
	close $rs;
	return \@out;
#	return \@rlist;
}

sub execCmd2
{
	my ($cmd) = @_;
	dbg_print("cmd : $cmd\n");
	my $res = `$cmd 2>&1`;
	my @array = split /\n/,$res;
#	print @array;
	return \@array;
}

# svn cmd [option] addres [args...]
sub svnCmd
{
	my ($cmd, $option, $address, $arg) = @_;
	my $user = getUserInfo();
	my $svnCmd = "svn $cmd $user $option $address $arg";
	return execCmd($svnCmd);
}

sub getUserInfo
{
	my $res = '';
	if( exists $gOptions->{'u'} ){
		$res = "--username $gOptions->{'u'}";
	}
	if( exists $gOptions->{'p'} ){
		$res = $res." --password  $gOptions->{'p'}";
	}
	return $res;
}

sub isInstallSVN
{
	my $res = execCmd('svn');
	if( $res->[0] =~ /svn help/ ){
		return 1;
	}
	return 0;
}

sub getDiffFileList
{
	my ($array) = @_;
	my @files = ();
	foreach my $line (@{$array}){
		if( $line =~ /^Index: (.+?)$/ ){
			push @files, $1;
		}
	}
	return \@files;
}

# ブランチの最初と最後のリビジョンを取得する
sub getRevisionNumber
{
	my ($svnrepo, $address, $option) = @_;

	print encode('cp932', "checking repository[$svnrepo]... [$address]\n");
	# --stop-on-copy を指定するとブランチができたポイントまでとなる
	# --verbose を指定すると追加／削除／変更がファイル単位で分かる
	
	my %outParam = (); # key{revision, fileList} として一旦束ねる
	%{$outParam{"fileList"}} = ();
	@{$outParam{"revision"}} = ();
	
	getLog($svnrepo, $address, $option, \%outParam);
	
	my $fileList = $outParam{"fileList"};
	my $revs = $outParam{"revision"};
	
	if( 0 == scalar(keys(%{$fileList})) ){
		die "[$address] is no history.\n"; # history log がない
	}
	return ($revs->[0], $revs->[scalar(@{$revs})-1], $fileList);
}

# svn からログを取得する（再帰)
sub getLog
{
	my ($svnrepo, $address, $option, $outParam, $from, $to) = @_;

	if( defined $from ){
		dbg_print("\n*** getLog [$svnrepo] [$address] [$option] [$from] [$to]\n");
	}
	else{
		dbg_print("\n*** getLog [$svnrepo] [$address] [$option] [undef] [undef]\n");
	}
	
	my $resArray = svnCmd("log", $option, "\"$address\"", "");

	my $fileList = $outParam->{"fileList"};
	my $revs = $outParam->{"revision"};
	
	while( my $line = pop(@{$resArray}) ){ # 過去からさかのぼる
		dbg_print($line);
		if( $line =~ /^r([0-9]+) |.+ lines$/ ){
			push @{$revs}, $1;
		}
		
		if( 1 <= @{$revs} ){
#			print encode('cp932',"line:$line");
			if( $line =~ /^   ([MADR]{1}) (\/.+)$/ ){
				my $type = $1; my $file = $2;
#				print encode('cp932', "MADR:$type:$file\n");
				if( $file =~ /(.+?) \(from (.+?)\:([0-9]+?)\)/ ){ # マージされている場合
					dbg_print("merge 1[$1] 2[$2] 3[$3]\n");
					my $now_from = $1; my $now_to = $2; my $now_rev = $3;
					if( defined $from ){ # 定義済みの場合、元のアドレスがあるので引き継ぐ
						getLog($svnrepo, $svnrepo.$now_to, "--stop-on-copy --verbose -r $now_rev ", $outParam, $from, $now_to);
					}
					else{
						getLog($svnrepo, $svnrepo.$now_to, "--stop-on-copy --verbose -r $now_rev ", $outParam, $now_from, $now_to);
					}
					next;
				}
				if( isDirectory($svnrepo, $file) ){
					next; # フォルダは無視する
				}
				
				if( defined $from ){ # 定義済みの場合、元のアドレスがあるので置き換える
					dbg_print("replace [$to] [$from] [$file]\n");
					if( $file !~ /$to/ ){
						next; # 対象外
					}
					$file =~ s/$to/$from/g;
				}
				
				dbg_print("target[$file]\n");
				# A 項目が追加されました。
				# D 項目が削除されました。
				# M 項目の属性やテキスト内容が変更されました。
				# R 項目が同じ場所の違うもので置き換えられました。
				if( exists $fileList->{$file} ){
					if( ($fileList->{$file} ne 'A') && ($type eq 'D') ){ # 最初が追加の場合は、上書きは削除しか認めない
						delete($fileList->{$file}); # 最初から無かったことにする
					}
					elsif( ($fileList->{$file} ne 'D') && ($type eq 'A') ){ # 最初が削除の場合は、上書きは追加しか認めない
						$fileList->{$file} = 'M'; # 変更扱いとしておく
					}
					else{
						$fileList->{$file} = $type;
					}
				}
				else{
					$fileList->{$file} = $type;
				}
			}
		}
	}
}

sub isDirectory
{
	my($svnrepo, $a2) = @_;
	
	my $res = svnCmd("info", '', $svnrepo.$a2, '');
 	my $string = join '', @{$res};
	if( $string =~ /Node Kind: directory/ ){ # 'Node Kind: file' by file.
 		return 1;
 	}
 	return 0;
}


sub getOptions
{
	my ($argv) = @_;
	my %options = ();
	my @newAragv = ();
	for(my $i=0; $i< @{$argv}; $i++){
		my $key = decode('cp932', $argv->[$i]);
		if( $key =~ /^-(u|p|report)$/ ){
			$options{$1} = decode('cp932', $argv->[$i+1]);
			$i++;
		}
		elsif( $key eq '-r' ){
			my $param = decode('cp932', $argv->[$i+1]);
			if( $param !~ /^(\d+):(\d+)$/ ) {
				die "illigal parameter with options ($key = $param)";
			}
			$options{'r_start'} = $1;
			$options{'r_end'} = $2;
			$i++;
		}
		elsif( $key =~ /^-(dbg|shortpath)$/ ){
			$options{$1} = 1;
		}
		elsif( $key =~ /^-/ ){
			die "illigal parameter with options ($key)";
		}
		else{
			push @newAragv, $key;
		}
	}
	return (\@newAragv, \%options);
}

