package FusionInventory::Agent::Task::WakeOnLan;

use strict;
use warnings;
use base 'FusionInventory::Agent::Task';

use English qw(-no_match_vars);
use List::Util qw(first);
use Socket;
use UNIVERSAL::require;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Network;

use FusionInventory::Agent::Task::WakeOnLan::Version;

our $VERSION = FusionInventory::Agent::Task::WakeOnLan::Version::VERSION;

sub isEnabled {
    my ($self, $response) = @_;

    if (!$self->{target}->isa('FusionInventory::Agent::Target::Server')) {
        $self->{logger}->debug("WakeOnLan task not compatible with local target");
        return;
    }

    my @options = $response->getOptionsInfoByName('WAKEONLAN');
    if (!@options) {
        $self->{logger}->debug("WakeOnLan task execution not requested");
        return;
    }

    my @addresses;
    foreach my $option (@options) {
        foreach my $param (@{$option->{PARAM}}) {
            my $address = $param->{MAC};
            if ($address !~ /^$mac_address_pattern$/) {
                $self->{logger}->error("invalid MAC address $address, skipping");
                next;
            }
            $address =~ s/://g;
            push @addresses, $address;
        }
    }

    if (!@addresses) {
        $self->{logger}->error("no mac address defined");
        return;
    }

    $self->{addresses} = \@addresses;
    return 1;
}

sub run {
    my ($self, %params) = @_;

    my @methods = $params{methods} ? @{$params{methods}} : qw/ethernet udp/;

    METHODS: foreach my $method (@methods) {
        my $function = '_send_magic_packet_' . $method;
        ADDRESSES: foreach my $address (@{$self->{addresses}}) {
            eval {
                $self->$function($address);
            };
            if ($EVAL_ERROR) {
                $self->{logger}->error(
                    "Impossible to use $method method: $EVAL_ERROR"
                );
                # this method doesn't work, skip remaining addresses
                last ADDRESSES;
            }
        }
        # all addresses have been processed, skip other methods
        last METHODS;
    }
}

sub _send_magic_packet_ethernet {
    my ($self, $target) = @_;

    die "root privileges needed\n" unless $UID == 0;
    die "Net::Write module needed\n" unless Net::Write::Layer2->require();

    for my $interface ( $self->_getInterfaces() ) {
        my $source = $interface->{MACADDR};
        $source =~ s/://g;
        my $dev = $interface->{DESCRIPTION};

        my $packet =
            pack('H12', $target) .
            pack('H12', $source) .
            pack('H4', "0842")   .
            $self->_getPayload($target);

        $self->{logger}->debug(
            "Sending magic packet to $target as ethernet frame on $dev"
        );

        my $writer = Net::Write::Layer2->new(
           dev => $dev
        );

        $writer->open();
        $writer->send($packet);
        $writer->close();
    }
}

sub _send_magic_packet_udp {
    my ($self,  $target) = @_;

    socket(my $socket, PF_INET, SOCK_DGRAM, getprotobyname('udp'))
        or die "can't open socket: $ERRNO\n";
    setsockopt($socket, SOL_SOCKET, SO_BROADCAST, 1)
        or die "can't do setsockopt: $ERRNO\n";

    my $packet = $self->_getPayload($target);
    my $destination = sockaddr_in("9", inet_aton("255.255.255.255"));

    $self->{logger}->debug(
        "Sending magic packet to $target as UDP packet"
    );
    send($socket, $packet, 0, $destination)
        or die "can't send packet: $ERRNO\n";
    close($socket);
}

sub _getInterfaces {
    my ($self) = @_;

    my @interfaces;

    SWITCH: {
        if ($OSNAME eq 'linux') {
            FusionInventory::Agent::Tools::Linux->require();
            @interfaces = FusionInventory::Agent::Tools::Linux::getInterfacesFromIfconfig(
                logger => $self->{logger}
            );
            last;
        }

        if ($OSNAME =~ /freebsd|openbsd|netbsd|gnukfreebsd|gnuknetbsd|dragonfly/) {
            FusionInventory::Agent::Tools::BSD->require();
            @interfaces = FusionInventory::Agent::Tools::BSD::getInterfacesFromIfconfig(
                logger => $self->{logger}
            );
            last;
        }

        if ($OSNAME eq 'MSWin32') {
            FusionInventory::Agent::Tools::Win32->require();
            @interfaces = FusionInventory::Agent::Tools::Win32::getInterfaces(
                logger => $self->{logger}
            );
            # on Windows, we have to use internal device name instead of litteral name
            for my $interface ( @interfaces ) {
                $interface->{DESCRIPTION} =
                    $self->_getWin32InterfaceId($interface->{PNPDEVICEID})
            }

            last;
        }
    }

    my @nonloopbackordumbinterfaces =
        grep { $_->{DESCRIPTION} ne 'lo' }
        grep { $_->{IPADDRESS} }
        grep { $_->{MACADDR} }
        @interfaces;

   return @nonloopbackordumbinterfaces;
}

sub _getInterface {
    my ($self) = @_;

    my @interfaces = $self->_getInterfaces();
    # let's take the first interface with an IP adress, a MAC address
    # different from the loopback
    my $interface =
        first { $_->{DESCRIPTION} ne 'lo' } # XXX This is already filtered in _getInterfaces()
        grep { $_->{IPADDRESS} }
        grep { $_->{MACADDR} }
        @interfaces;

    return $interface;
}

sub _getPayload {
    my ($self, $target) = @_;

    return
        pack('H12', 'FF' x 6) .
        pack('H12', $target) x 16;
}

sub _getWin32InterfaceId {
    my ($self, $pnpid) = @_;

    FusionInventory::Agent::Tools::Win32->require();

    my $key = FusionInventory::Agent::Tools::Win32::getRegistryKey(
        path => "HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/Network",
    );

    foreach my $subkey_id (keys %$key) {
        # we're only interested in GUID subkeys
        next unless $subkey_id =~ /^\{\S+\}\/$/;
        my $subkey = $key->{$subkey_id};
        foreach my $subsubkey_id (keys %$subkey) {
            my $subsubkey = $subkey->{$subsubkey_id};
            next unless $subsubkey->{'Connection/'};
            next unless $subsubkey->{'Connection/'}->{'/PnpInstanceID'};
            next unless $subsubkey->{'Connection/'}->{'/PnpInstanceID'} eq $pnpid;
            my $device_id = $subsubkey_id;
            $device_id =~ s{/$}{};

            return '\Device\NPF_' . $device_id;
        }
    }

}

1;
__END__

=head1 NAME

FusionInventory::Agent::Task::WakeOnLan - Wake-on-lan task for FusionInventory

=head1 DESCRIPTION

This task send a wake-on-lan packet to another host on the same network as the
agent host.
