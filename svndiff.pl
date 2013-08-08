#<!-- -*- encoding: utf-8n -*- -->
use strict;
use warnings;
use utf8;

use Cwd;
use Encode;
use Encode::JP;

use Data::Dumper;

print "svndiff ver. 0.13.08.08.\n";
my ($argv, $gOptions) = getOptions(\@ARGV); # オプションを抜き出す
my $args = @{$argv};

if( $args != 3 ){
	print "Usage: svndiff [options] <svn repo> <svn address> <output path>\n";
	print "  options : -u : user.\n";
	print "          : -p : password.\n";
	print "          : -r (start:end) : revsion number.\n";
	print "          : -report (fileNmae) : output add/del/mod report.\n";
	print "          : -d (path) : output delete path.\n";
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
my $svnrepo = $argv->[0];
my $address = $argv->[1];
my $outputPath  = $argv->[2];

# オプション指定でリビジョンが存在か確認
if( exists $gOptions->{'r_start'} ){
	# オプション指定がある
	($srev, $erev, $fileList) = getRevisionNumber($address, "-r $gOptions->{'r_end'}:$gOptions->{'r_start'} --verbose" );
}
else{
	# ブランチの最初と最後のリビジョンを取得する
	($srev, $erev, $fileList) = getRevisionNumber($address, "--stop-on-copy --verbose" );
}

#my $diffres = svnCmd("diff","-r $srev:$erev", "\"$address\"", "");
#print encode('cp932', "diff ".join '', @{$diffres});
#my $files = getDiffFileList($diffres);

my $sErrorFile = svnExportFiles("$srev", $svnrepo, $address, $fileList, $outputPath, $gOptions->{'d'}); # 開始
my $eErrorFile = svnExportFiles("$erev", $svnrepo, $address, $fileList, $outputPath, $gOptions->{'d'}); # 終了

#if( 0 != @{$sErrorFile} ){
#	print encode('cp932', "illigalFile file list\n");
#	foreach my $file (@{$sErrorFile}){
#		print encode('cp932', "\[$file\]\n");
#	}
#}
if( exists $gOptions->{'report'} ){
	exportReport( "$outputPath\/$gOptions->{'report'}", $fileList, $gOptions->{'d'});
}

putDeletedList($fileList);

print "complate.\n";
exit;

sub dbg_print
{
	my ($string) = @_;
	if( defined $gOptions->{'dbg'} ){
		print encode('cp932', $string);
	}
}

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

	print "export report.[$file]\n";
	
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
#			print encode('cp932', "--- paths---\n[$paths]\n");
		}
		$paths = $paths."\/";
	}
}

sub svnExportFiles
{
	my ($rev, $svnrepo, $address, $files, $path, $deletePath) = @_;

	print "exporting rev\.$rev\...\n";
	
	$path = $path."\/$rev";
	my @notFoundFile = ();
	foreach my $file ( keys %{$files} ){
		if( $file !~ /\..+?$/ ){
			next; # フォルダなんで無視（T.B.D）
		}
#		if( 'D' eq $files->{$file} ){
#			next; # 削除ファイルは出力しない。
#		}
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
		
		my $res = svnCmd("export", "-r $rev --force", "\"$svnrepo"."$file\"", "\"$outFilePath\"");
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
	my ($address, $option) = @_;

	print "checking repository... [$address]\n";
	# --stop-on-copy を指定するとブランチができたポイントまでとなる
	# --verbose を指定すると追加／削除／変更がファイル単位で分かる
	my $resArray = svnCmd("log", $option, "\"$address\"", "");
	
	my @revs = ();
	my %fileList = ();
	while( my $line = pop(@{$resArray}) ){ # 過去からさかのぼる
		dbg_print($line);
		if( $line =~ /^r([0-9]+) |.+ lines$/ ){
			push @revs, $1;
		}
		
		if( 1 <= @revs ){
			if( $line =~ /^   ([MADR]{1}) (\/.+?)$/ ){
				my $a1 = $1; my $a2 = $2;
				if( $a2 =~ /\(from .+\)/ ){
					next; # 意味不明フォルダなんでfilelistの対象としない
				}
				# A 項目が追加されました。
				# D 項目が削除されました。
				# M 項目の属性やテキスト内容が変更されました。
				# R 項目が同じ場所の違うもので置き換えられました。
				if( exists $fileList{$a2} ){
					if( ($fileList{$a2} ne 'A') && ($a1 eq 'D') ){ # 最初が追加の場合は、上書きは削除しか認めない
						delete($fileList{$a2}); # 最初から無かったことにする
					}
					elsif( ($fileList{$a2} ne 'D') && ($a1 eq 'A') ){ # 最初が削除の場合は、上書きは追加しか認めない
						$fileList{$a2} = 'M'; # 変更扱いとしておく
					}
				else{
					$fileList{$a2} = $a1;
				}
				}
				else{
					$fileList{$a2} = $a1;
				}
			}
		}
	}
	if( 1 >= @revs ){
		die "[$address] is no history.\n";
	}
	return ($revs[0], $revs[$#revs], \%fileList);
}

sub getOptions
{
	my ($argv) = @_;
	my %options = ();
	my @newAragv = ();
	for(my $i=0; $i< @{$argv}; $i++){
		my $key = decode('cp932', $argv->[$i]);
		if( $key =~ /^-(u|p|report|d)$/ ){
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
		elsif( $key =~ /^-(dbg)$/ ){
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

