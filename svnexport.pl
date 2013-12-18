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

print "svnexport ver. 0.13.11.26.\n";
my %gOptions = ();
my $argv = getOptions(\@ARGV,\%gOptions); # オプションを抜き出す
if( scalar(@{$argv}) != 2 ){
	print "Usage: svnexport [options] <svn address> <output path>\n";
	print "  options : -u : user.\n";
	print "          : -p : password.\n";
	print "          : -r [revision] : revsion number.\n";
	print "https://github.com/oya3/svndiff\n";
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
my $svnrepo = getRepositoryRoot($address);
print "Repository Root: $svnrepo\n";

# オプション指定でリビジョンが存在か確認
if( !exists $gOptions{'r'} ){
	# オプション指定がある
	$gOptions{'r'} = getBaseRevisionNumber($svnrepo, $address); # そのブランチの最初
}
my $outpath = "$outputPath\/base_$gOptions{'r'}";
my $cmd = "svn export -r $gOptions{'r'} \"$address\" \"$outpath\"";
my $cmd_sjis = encode('cp932', $cmd);
`$cmd_sjis`;
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
	if( defined $gOptions{'dbg'} ){
		print encode('cp932', $string);
	}
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
}

sub execCmd2
{
	my ($cmd) = @_;
	dbg_print("cmd : $cmd\n");
	my $res = `$cmd 2>&1`;
	my @array = split /\n/,$res;
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
	if( exists $gOptions{'u'} ){
		$res = "--username $gOptions{'u'}";
	}
	if( exists $gOptions{'p'} ){
		$res = $res." --password  $gOptions{'p'}";
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

# ブランチの最初と最後のリビジョンを取得する
sub getBaseRevisionNumber
{
	my ($svnrepo, $address) = @_;

	# --stop-on-copy を指定するとブランチができたポイントまでとなる
	# --verbose を指定すると追加／削除／変更がファイル単位で分かる
	print encode('cp932', "checking repository[$svnrepo]... [$address]\n");
	 
	my $resArray = svnCmd("log", "--stop-on-copy", "\"$address\"", "");
	#print encode('cp932', Dumper($resArray));

	#          r808 | fukusumi | 2013-11-22 14:28:45 +0900 (金, 22 11 2013) | 2 lines
	my $r = 0;
	while( my $line = pop(@{$resArray}) ){ # 過去からさかのぼる
		chomp $line;
		#print encode('cp932', $line."\n");
		#if( $line =~ /^\s*r(\d+)\s+\|\s+.+?\s+\|\s+\d{4}\-\d{1,2}\-\d{1,2}\-/ ){
		if( $line =~ /^\s*r(\d+)\s+\|\s+.+?\s+\|\s+\d{4}+\-\d{1,2}\-\d{1,2}\s+/ ){
			$r=$1;
			last;
		}
	}
	return $r;
}

sub getOptions
{
	my ($argv,$options) = @_;
	my @newAragv = ();
	for(my $i=0; $i< @{$argv}; $i++){
		my $key = decode('cp932', $argv->[$i]);
		if( $key =~ /^-(u|p)$/ ){
			$options->{$1} = decode('cp932', $argv->[$i+1]);
			$i++;
		}
		elsif( $key eq '-r' ){
			my $param = decode('cp932', $argv->[$i+1]);
			if( $param !~ /^(\d+)$/ ) {
				die "illigal parameter with options ($key = $param)";
			}
			$options->{'r'} = $1;
			$i++;
		}
		elsif( $key =~ /^-(dbg|shortpath)$/ ){
			$options->{$1} = 1;
		}
		elsif( $key =~ /^-/ ){
			die "illigal parameter with options ($key)";
		}
		else{
			push @newAragv, $key;
		}
	}
	return (\@newAragv);
}

