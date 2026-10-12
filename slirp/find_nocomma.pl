use strict;
use warnings;
my $count = 0;
# Proper K&R function-definition line: name(ident ident[ ident...])  with at least 2 space-separated & no comma/star
my @files = (glob('src/*.c'), glob('src/ppp/*.c'));
foreach my $f (@files) {
    next if !-e $f;
    open my $fh, '<', $f or next;
    my $lineno = 0;
    while (my $line = <$fh>) {
        $lineno++;
        next if $line =~ m{^\s*(?:/\*|\*)};
        $line =~ s/\r$//;
        if ($line =~ /^([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)((?:\s+[A-Za-z_][A-Za-z0-9_]*)+)\)[ \t]*$/) {
            my ($name, $p1, $rest) = ($1, $2, $3);
            my $args = "$p1$rest";
            next if $args =~ /[,*]/;
            print "$f:$lineno: $name($args)\n";
            $count++;
        }
    }
    close $fh;
}
print "TOTAL=$count\n";