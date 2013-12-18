#<!-- -*- encoding: utf-8n -*- -->
use strict;
use warnings;
use utf8;

use Cwd;
use Encode;
use Encode::JP;

use FindBin;
#use lib "$FindBin::Bin/modules";

use Data::Dumper;
{
    package Data::Dumper;
	no warnings 'redefine'; # 関数再定義警告を無効
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;

print "allsvnexport ver. 0.13.11.29.\n";
my %gOptions = ();
my $argv = getOptions(\@ARGV, \%gOptions);
if( scalar(@{$argv}) != 1 ){
	print "Usage: allsvnexport [options] <list.txt>\n";
	print "  options : -u [user] : user.\n";
	print "          : -p [password] : password.\n";
	print "https://github.com/oya3/svndiff\n";
    exit;
}

my $list = readListFile($argv->[0]);
#print encode('cp932', Dumper(\%gOptions));
my $opt = '';
if( exists $gOptions{'u'} ){
	$opt .= "-u $gOptions{'u'} "
}
if( exists $gOptions{'p'} ){
	$opt .= "-p $gOptions{'u'} "
}
foreach my $param (@{$list}){
	#print encode('cp932', "[$param->{'name'}][$param->{'address'}]\n");
	mkdir encode('cp932', "$param->{'name'}");
	print encode('cp932', "output[$param->{'name'}]\n");
	
	if( $param->{'address'} =~ /^http\:\/\// ){
		my $cmd =  "perl $FindBin::Bin/svnexport.pl $opt \"$param->{'address'}\" \"$param->{'name'}\"";
		my $cmd_sjis = encode('cp932', $cmd);
		`$cmd_sjis`;
	}
}
print "complate.\n";
exit;

sub readListFile
{
	my ($file) = @_;
	my $file_sjis = encode('cp932', $file);
	open (IN, "<$file_sjis") or die "[$file_sjis]$!";
	my @body = <IN> ;
	close IN;
	my @out = ();
	foreach my $line (@body) {
		$line = decode('cp932', $line);
		chomp $line;
		if( $line =~ /^\s*(\#|$)/ ){
			# 空行、コメントは無視
			next;
		}
		elsif( $line =~ /^\s*(.+?)\s*,\s*(.+?)\s*$/ ){
			my %param = ();
			$param{'name'} = $1;
			$param{'address'} = $2;
			push @out, \%param;
		}
		else{
			print encode('cp932', "[$file]フォーマット異常[$line]\n");
		}
	}
	return \@out;
}

sub getOptions
{
	my ($argv,$options) = @_;
	my @newAragv = ();
	for(my $i=0; $i< @{$argv}; $i++){
		my $key = decode('cp932', $argv->[$i]);
		if( $key =~ /^-(report)$/ ){
			$options->{$1} = decode('cp932', $argv->[$i+1]);
			$i++;
		}
		elsif( $key =~ /^-(shortpath)$/ ){
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

