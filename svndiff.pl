#<!-- -*- encoding: utf-8n -*- -->
use strict;
use warnings;
use utf8;

use Cwd;
use Encode;
use Encode::JP;

print "svndiff ver. 0.13.08.02.\n";
my ($argv, $gOptions) = getOptions(\@ARGV); # オプションを抜き出す
my $args = @{$argv};

if( $args != 2 ){
	print "Usage: svndiff [options] <svn address> <output path>\n";
	print "  options : -u : user.\n";
	print "          : -p : password.\n";
	print "          : -r (start:end) : revsion number.\n";
	print "          : -report (fileNmae) : output add/del/mod report.\n";
    exit;
}

if( !isInstallSVN() ){
	die "svn not installed.";
}

my $fileList = undef;
my $srev = '';
my $erev = '';
my $address = $argv->[0];
my $outputPath  = $argv->[1];

# オプション指定でリビジョンが存在か確認
if( exists $gOptions->{'-r_start'} ){
	# オプション指定がある
	$srev = $gOptions->{'-r_start'};
	$erev = $gOptions->{'-r_end'};
}
else{
	# ブランチの最初と最後のリビジョンを取得する
	($srev, $erev, $fileList) = getRevisionNumber($address);
}
my $diffres = svnCmd("diff","-r $srev:$erev", $address, "");
my $files = getDiffFileList($diffres);

exportFiles($srev, $address, $files, $outputPath);
exportFiles($erev, $address, $files, $outputPath);
if( exists $gOptions->{'-report'} ){
	exportReport( "$outputPath\/$gOptions->{'-report'}", $fileList);
}
print "complate.\n";
exit;


sub exportReport
{
	my ($file,$fileList) = @_;

	my $file_sjis = encode('cp932', $file);
	my %keys = ("A"=>"追加", "D"=>"削除", "M"=>"変更", "R"=>"置換");
	
	open (OUT, ">$file_sjis") or die "$!";
	foreach my $file ( sort keys %{$fileList} ){
		my $sts = $fileList->{$file};
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

sub exportFiles
{
	my ($rev, $address, $files, $path) = @_;

	$path = $path."\/$rev";
	foreach my $file (@{$files}){
		my $dir = "$path\/$file";
		$dir =~ s/^(.+)[\\\/].+$/$1/;
		#mkpath encode('cp932', $dir);
		_mkdir $dir;
		
		my $res = svnCmd("export", "-r $rev", "$address\/$file", "$path\/$file");
		#print @{$res};
	}
}

sub execCmd
{
	my ($cmd) = @_;
	$cmd = encode('cp932', $cmd);
	print "cmd : $cmd\n";
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
	print encode('cp932', "cmd : $cmd\n");
	my $res = `$cmd 2>&1`;
	my @array = split /\n/,$res;
	print @array;
	return \@array;
}

# svn cmd [option] addres [args...]
sub svnCmd
{
	my ($cmd, $option, $address, $arg) = @_;
	my $user = getUserInfo();
	my $svnCmd = "svn $cmd $user $option \"$address\" $arg";
	return execCmd($svnCmd);
}

sub getUserInfo
{
	my $res = '';
	if( exists $gOptions->{'-u'} ){
		$res = "--username $gOptions->{'-u'}";
	}
	if( exists $gOptions->{'-p'} ){
		$res = $res." --password  $gOptions->{'-p'}";
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
	my ($address) = @_;
	# --stop-on-copy を指定するとブランチができたポイントまでとなる
	# --verbose を指定すると追加／削除／変更がファイル単位で分かる
	my $resArray = svnCmd("log", "--stop-on-copy --verbose", "$address", "");
	
	my @revs = ();
	my %fileList = ();
	while( my $line = pop(@{$resArray}) ){ # 過去からさかのぼる
		# exe : r1993 | k-oya | 2013-07-22 22:24:36 +0900 (月, 22 7 2013) | 3 lines
		if( $line =~ /^r([0-9]+) |.+ lines$/ ){
			push @revs, $1;
		}
		elsif( $line =~ /^   ([MADR]{1}) (\/.+?)$/ ){
			my $a1 = $1; my $a2 = $2;
			if( $a2 =~ /\(from .+\)/ ){
				next; # フォルダなんでfilelistの対象としない
			}
			# A 項目が追加されました。
			# D 項目が削除されました。
			# M 項目の属性やテキスト内容が変更されました。
			# R 項目が同じ場所の違うもので置き換えられました。
			if( exists $fileList{$a2} ){
				if( $a1 =~ /^[AD]$/ ){
					$fileList{$a2} = $a1;
				}
			}
			else{
				$fileList{$a2} = $a1;
			}
			
		}
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
		if( $key =~ /^-(u|p|report)$/ ){
			$options{$key} = decode('cp932', $argv->[$i+1]);
			$i++;
		}
		elsif( $key eq '-r' ){
			my $param = decode('cp932', $argv->[$i+1]);
			if( $param !~ /^(%d):(%d)$/ ) {
				die "illigal parameter with options ($param)";
			}
			$options{'-r_start'} = $1;
			$options{'-r_end'} = $2;
			$i++;
		}
		else{
			push @newAragv, $key;
		}
	}
	return (\@newAragv, \%options);
}

