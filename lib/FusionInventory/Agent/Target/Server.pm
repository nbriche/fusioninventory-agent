package FusionInventory::Agent::Target::Server;

use strict;
use warnings;
use base 'FusionInventory::Agent::Target';

use English qw(-no_match_vars);
use URI;

my $count = 0;

sub new {
    my ($class, %params) = @_;

    die "no url parameter" unless $params{url};

    my $self = $class->SUPER::new(%params);

    $self->{url} = _getCanonicalURL($params{url});

    # compute storage subdirectory from url
    my $subdir = $self->{url};
    $subdir =~ s/\//_/g;
    $subdir =~ s/:/../g if $OSNAME eq 'MSWin32';

    $self->_init(
        id     => 'server' . $count++,
        vardir => $params{basevardir} . '/' . $subdir
    );

    my $logger = $self->{logger};

    $self->{accountinfo} = $self->{myData}->{accountinfo};

    if ($params{tag}) {
        if ($self->{accountinfo}->{TAG}) {
            $logger->debug(
                "A TAG seems to already exist in the server for this ".
                "machine. The -t parameter may be ignored by the server " .
                "unless it has OCS_OPT_ACCEPT_TAG_UPDATE_FROM_CLIENT=1."
            );
        }
        $self->{accountinfo}->{TAG} = $params{tag};
    }

    return $self;
}

sub _getCanonicalURL {
    my ($string) = @_;

    my $url = URI->new($string);

    my $scheme = $url->scheme();
    if (!$scheme) {
        # this is likely a bare hostname
        # as parsing relies on scheme, host and path have to be set explicitely
        $url->scheme('http');
        $url->host($string);
        $url->path('ocsinventory');
    } else {
        die "invalid protocol for URL: $string"
            if $scheme ne 'http' && $scheme ne 'https';
        # complete path if needed
        $url->path('ocsinventory') if !$url->path();
    }

    return $url;
}

sub getUrl {
    my ($self) = @_;

    return $self->{url};
}

sub getDescription {
    my ($self) = @_;

    return "server, $self->{url}";
}

sub getAccountInfo {
    my ($self) = @_;

    return $self->{accountInfo};
}

sub setAccountInfo {
    my ($self, $accountInfo) = @_;

    $self->{accountInfo} = $accountInfo;
}

sub _loadState {
    my ($self) = @_;

    my $data = $self->{storage}->restore();

    $self->{maxDelay}    = $data->{maxDelay}    if $data->{maxDelay};
    $self->{nextRunDate} = $data->{nextRunDate} if $data->{nextRunDate};
    $self->{accountInfo} = $data->{accountInfo} if $data->{accountInfo};
}

sub _saveState {
    my ($self) = @_;

    $self->{storage}->save(data => {
        maxDelay    => $self->{maxDelay},
        nextRunDate => $self->{nextRunDate},
        accountInfo => $self->{accountInfo},
    });
}

1;

__END__

=head1 NAME

FusionInventory::Agent::Target::Server - Server target

=head1 DESCRIPTION

This is a target for sending execution result to a server.

=head1 METHODS

=head2 new(%params)

The constructor. The following parameters are allowed, in addition to those
from the base class C<FusionInventory::Agent::Target>, as keys of the %params
hash:

=over

=item I<url>

the server URL (mandatory)

=back

=head2 getUrl()

Return the server URL for this target.

=head2 getAccountInfo()

Get account informations for this target.

=head2 setAccountInfo($info)

Set account informations for this target.
