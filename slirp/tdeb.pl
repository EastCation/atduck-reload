use strict;
my $re = '^([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)((?:\s+[A-Za-z_][A-Za-z0-9_]*)+)\)[ \t]*\r?\n?$';
my @tests = (
  "ip_reass(ip fp)\n",
  "ip_reass(ip fp)\r\n",
  "ip_reass(ip fp) \n",
  "ip_reass(ip fp)\n",
);
for my $t (@tests) {
  my $orig = $t;
  my $len = length $t;
  $t =~ s/\r$//;
  if ($t =~ /$re/) {
    print "MATCH len=$len [", $orig, "] => name=$1 args=$2$3\n";
  } else {
    print "NOMATCH len=$len [", $orig, "]\n";
  }
}
# now real file
open my $fh, '<', 'src/ip_input.c' or die $!;
my @l = <$fh>;
close $fh;
my $line = $l[238];
printf "file L239 len(pre-strip)=%d\n", length($line);
$line =~ s/\r$//;
printf "file L239 len(post-strip)=%d [%s]\n", length($line), $line;
printf "file L239 tail-hex=%s\n", unpack("H*", substr($line, -6));
if ($line =~ /$re/) { print "file MATCH name=$1 args=$2$3\n"; }
else { print "file NOMATCH\n"; }