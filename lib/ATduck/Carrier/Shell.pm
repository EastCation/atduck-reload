package ATduck::Carrier::Shell;
# This file is part of ATduck
use POSIX;
use IPC::Open2;
use ATduck::Carrier;
use warnings;
use strict;

our @ISA = qw(ATduck::Carrier);

# IO::Pty is unavailable on native (Strawberry) Windows. When it is missing,
# subprocesses (e.g. SLiRP) are connected through plain pipes instead of a
# PTY, so the `usepty` flag is silently downgraded.
my $HAVE_IO_PTY;
$HAVE_IO_PTY = eval 'use IO::Pty; 1';

sub new {
    my ($class, $modem, $arg) = @_;
    my $self = $class->SUPER::new($arg);
    bless($self, $class);

    # Set up subprocess environment
    $self->_pty() if $self->{usepty};
    local $ENV{M_RATE} = $ATduck::Modem::rate;
    local $ENV{SLIRP_TTY} = local $ENV{M_TTYPATH} =
        $self->_pty('path') if $self->{pty};
    local $ENV{M_TTYNAME} = $self->_pty('name') if $self->{pty};
    local $ENV{TERM} = 'vt100';
    $self->{pid} = open2($self->{readpipe}, $self->{writepipe},
                         $self->_shell(), '-c', $self->{data});
    # Check that open2 succeeded
    return undef unless $self->{pid};
    # Set up filehandles
    if ( $self->{pty} ) { $self->register($self->{pty}) }
    else { $self->register($self->{readpipe}, $self->{writepipe}) }

    return $self;
}

# Choose a shell for the subprocess. Cygwin and Unix have `sh`; native
# Windows usually does not have `sh` on PATH, but Git for Windows ships
# one. Fall back to Git's install locations so the dialing plan's POSIX
# script can still run even when PATH is not set up for it.
sub _shell {
    return 'sh' if $^O !~ /MSWin32/i;
    foreach my $candidate (
        'C:/Program Files/Git/bin/sh.exe',
        'C:/Program Files/Git/usr/bin/sh.exe',
        'C:/Program Files (x86)/Git/bin/sh.exe',
        'C:/Program Files/Git/usr/bin/bash.exe',
        'C:/Program Files (x86)/Git/usr/bin/bash.exe',
    ) {
        return $candidate if -e $candidate;
    }
    return 'sh';    # no Git shell found; let open2 report the failure clearly
}

# Allocate a PTY to use instead of STDIN/STDOUT
sub _pty {
    my ($self, $flag) = @_;
    if ( !$self->{pty} ) {
        # Native (Strawberry) Windows has no IO::Pty; fall back to plain
        # stdio pipes so subprocesses like SLiRP can still run in slip mode.
        # Note: refer to the class through a string so strict 'subs' is
        # happy even when IO::Pty is only loaded lazily at runtime.
        return undef unless $HAVE_IO_PTY;
        my $pty_class = 'IO::Pty';
        $self->{pty} = $pty_class->new();
        # Turn off echo and other unplesantness.
        # Required on cygwin because subprocesses have incredible overhead,
        # and by the time SLiRP finally gets around to setting up the PTY,
        # the dialer may have already received the CONNECT response, started
        # sending data, received echoed data back, and given up on account
        # of "line echo".
        #
        # So let's just avoid that. The settings below are from SLiRP.
        my $termios = POSIX::Termios->new();
        my $fileno = fileno($self->{pty});
        $termios->getattr($fileno);
        # Note: fileno might be zero, but we don't expect to fiddle with STDIN.
        if ( $fileno && $termios ) {
            $termios->setiflag(0);
            $termios->setoflag(0);
            $termios->setlflag(0);
            $termios->setcc(&POSIX::VMIN, 1);
            $termios->setcc(&POSIX::VTIME, 0);
            $termios->setattr($fileno, &POSIX::TCSANOW);
        }
        # FIXME debug
        #info($m, 'Allocated Terminal: '.$m->{carrier}{pty}->ttyname());
    }
    return unless $flag;
    my $fn = $self->{pty}->ttyname();
    $fn =~ s/^\/dev\/// if $flag eq 'name';
    return $fn;
}

sub DESTROY {
    my ($self) = @_;
    $self->SUPER::DESTROY(@_);
    # Also close non-registered file handles
    foreach ( qw/readpipe writepipe pty/ ) {
        close($self->{$_}) if $self->{$_};
    }
    # Also kill child process
    if ( $self->{pid} > 1 ) {
        local $SIG{CHLD} = 'IGNORE';
        kill 15, $self->{pid} foreach 'SIGHUP', 'SIGINT';
        waitpid $self->{pid}, 0; # FIXME: What if this takes a long time?
    }
}

1;