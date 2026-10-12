package ATduck::Transport::Pty;
# This file is part of ATduck
use ATduck::Transport;
use warnings;
use strict;

our @ISA = qw(ATduck::Transport);

ATduck::Main->install_transport(__PACKAGE__, 'PTY');

# Load IO::Pty lazily: it is unavailable on native (Strawberry) Windows, so
# merely installing this transport must not prevent ATduck from starting.
sub _ensure_pty {
    return 1 if defined &IO::Pty::new;
    eval 'use IO::Pty; 1' or
        die "PTY transport requires the IO::Pty module: $@";
    return 1;
}

sub new_client {
    my $class = shift @_;
    my $self = $class->SUPER::new_client(@_);
    bless($self, $class);
    $class->_ensure_pty();
    my $pty = IO::Pty->new();
    $self->register($pty);
    if ( $self->{file} ) {
        unlink $self->{file} if -l $self->{file};
        symlink $pty->ttyname(), $self->{file}
            or die "Couldn't create pty symlink: $!\n";
    }
    return $self;
}

sub new_server { die "This transport cannot be used as a listener\n" }

sub parse {
    my ($self, $str) = @_;
    return $str ? { file => $str } : {};
}

sub detect { return   0 }

sub accept { die }

1;