package FusionInventory::Agent::XML::Query::Inventory;
# TODO: resort the functions
use strict;
use warnings;

=head1 NAME

FusionInventory::Agent::XML::Query::Inventory - the XML abstraction layer

=head1 DESCRIPTION

FusionInventory uses OCS Inventory XML format for the data transmition. This
module is the abstraction layer. It's mostly used in the backend module where
it called $inventory in general.

=cut

use Encode qw/encode/;
use XML::Simple;
use Digest::MD5 qw(md5_base64);
use Config;
use FusionInventory::Agent::XML::Query;

use FusionInventory::Agent::Task::Inventory;

our @ISA = ('FusionInventory::Agent::XML::Query');

=over 4

=item new()

The usual constructor.

=cut
sub new {
  my ($class, $params) = @_;

  my $self = $class->SUPER::new($params);
  bless ($self, $class);

  $self->{backend} = $params->{backend};
  my $logger = $self->{logger};
  my $target = $self->{target};
  my $config = $self->{config};

  if (!($target->{deviceid})) {
    $logger->fault ('deviceid unititalised!');
  }

  $self->{h}{QUERY} = ['INVENTORY'];
  $self->{h}{CONTENT}{ACCESSLOG} = {};
  $self->{h}{CONTENT}{BIOS} = {};
  $self->{h}{CONTENT}{CONTROLLERS} = [];
  $self->{h}{CONTENT}{CPUS} = [];
  $self->{h}{CONTENT}{DRIVES} = [];
  $self->{h}{CONTENT}{HARDWARE} = {
    # TODO move that in a backend module
    ARCHNAME => [$Config{archname}],
    VMSYSTEM => ["Physical"] # Default value
  };
  $self->{h}{CONTENT}{MONITORS} = [];
  $self->{h}{CONTENT}{PORTS} = [];
  $self->{h}{CONTENT}{SLOTS} = [];
  $self->{h}{CONTENT}{STORAGES} = [];
  $self->{h}{CONTENT}{SOFTWARES} = [];
  $self->{h}{CONTENT}{USERS} = [];
  $self->{h}{CONTENT}{VIDEOS} = [];
  $self->{h}{CONTENT}{VIRTUALMACHINES} = [];
  $self->{h}{CONTENT}{SOUNDS} = [];
  $self->{h}{CONTENT}{MODEMS} = [];
  $self->{h}{CONTENT}{ENVS} = [];
  $self->{h}{CONTENT}{UPDATES} = [];
  $self->{h}{CONTENT}{USBDEVICES} = [];
  $self->{h}{CONTENT}{BATTERIES} = [];
  $self->{h}{CONTENT}{VERSIONCLIENT} = ['FusionInventory-Agent_v'.$config->{VERSION}];

  # Is the XML centent initialised?
  $self->{isInitialised} = undef;

  return $self;
}

sub _addEntry {
    my ($self, $params) = @_;

    my $config = $self->{config};

    my $fields = $params->{'field'};
    my $sectionName = $params->{'sectionName'};
    my $values = $params->{'values'};
    my $noDuplicated = $params->{'noDuplicated'};

    my $newEntry;

    my $showAll = 0;

    foreach (@$fields) {
        if (!$showAll && !$values->{$_}) {
            next;
        }
        my $string = $self->_encode({ string => $values->{$_} }) || '';
        $newEntry->{$_}[0] = $string;
    }

# Don't create two time the same device
    ENTRY: foreach my $entry (@{$self->{h}{CONTENT}{$sectionName}}) {
        foreach (@$fields) {
            next ENTRY unless defined($entry->{$_}[0]) && 
defined($newEntry->{$_}[0]);
            next ENTRY if $entry->{$_}[0] ne $newEntry->{$_}[0];
        }
        return;
    }

    push @{$self->{h}{CONTENT}{$sectionName}}, $newEntry;

}

sub _encode {
    my ($self, $params) = @_;

    my $string = $params->{string};

    my $logger = $self->{logger};

    my $ret;

    $string =~ s/\0//g;

    $string =~  s/\r|\n//g;


    if ($string !~ m/\A(
      [\x09\x0A\x0D\x20-\x7E]            # ASCII
      | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
      |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
      | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
      |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
      |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
      | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
      |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
      )*\z/x) {
        $logger->debug("Non-UTF8 string: $string");
        return encode("UTF-8", $string);
  } else {
      return $string;
  }
}

=item initialise()

Runs the backend modules to initilise the data.

=cut
sub initialise {
  my ($self) = @_;

  return if $self->{isInitialised};

  $self->{backend}->feedInventory ({inventory => $self});

}

=item addController()

Add a controller in the inventory.

=cut
sub addController {
  my ($self, $args) = @_;

  my @fields = qw/
      DRIVER
      NAME
      MANUFACTURER
      PCICLASS
      PCIID
      PCISUBSYSTEMID
      PCISLOT
      TYPE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'CONTROLLERS',
        'values' => $args,
        });
}

=item addModem()

Add a modem in the inventory.

=cut
sub addModem {
  my ($self, $args) = @_;

  my @fields = qw/
      DESCRIPTION
      NAME
      /;


  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'MODEMS',
        'values' => $args,
        });
}
# For compatibiliy
sub addModems {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addModems to addModem()");
   $self->addModem(@_);
}

=item addDrive()

Add a partition in the inventory.

=cut
sub addDrive {
  my ($self, $args) = @_;

  my @fields = qw/
      CREATEDATE
      DESCRIPTION
      FREE
      FILESYSTEM
      LABEL
      LETTER
      SERIAL
      SYSTEMDRIVE
      TOTAL
      TYPE
      VOLUMN
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'DRIVES',
        'values' => $args,
        });
}
# For compatibiliy
sub addDrives {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addDrives to addDrive()");
   $self->addDrive(@_);
}

=item addStorage()

Add a storage system (hard drive, USB key, SAN volume, etc) in the inventory.

=cut
sub addStorage {
  my ($self, $args) = @_;

  my $logger = $self->{logger};

  my @fields = qw/
      DESCRIPTION
      DISKSIZE
      INTERFACE
      MANUFACTURER
      MODEL
      NAME
      TYPE
      SERIAL
      SERIALNUMBER
      FIRMWARE
      SCSI_COID
      SCSI_CHID
      SCSI_UNID
      SCSI_LUN
      /;

  my $values = $args;
  if (!$values->{serialnumber}) {
      $values->{serialnumber} = $values->{serial}
  }

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'STORAGES',
        'values' => $values,
        });
}
# For compatibiliy
sub addStorages {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addStorages to addStorage()");
   $self->addStorage(@_);
}


=item addMemory()

Add a memory module in the inventory.

=cut
sub addMemory {
  my ($self, $args) = @_;

  my @fields = qw/
      CAPACITY
      CAPTION
      FORMFACTOR
      REMOVABLE
      PURPOSE
      SPEED
      SERIALNUMBER
      TYPE
      DESCRIPTION
      NUMSLOTS
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'MEMORIES',
        'values' => $args,
        });
}
# For compatibiliy
sub addMemories {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addMemories to addMemory()");
   $self->addMemory(@_);
}

=item addPort()

Add a port module in the inventory.

=cut
sub addPorts{
  my ($self, $args) = @_;

  my @fields = qw/
      CAPTION
      DESCRIPTION
      NAME
      TYPE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'PORTS',
        'values' => $args,
        });
}
# For compatibiliy
sub addPort {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addPorts to addPort()");
   $self->addPort(@_);
}

=item addSlot()

Add a slot in the inventory. 

=cut
sub addSlot {
  my ($self, $args) = @_;

  my @fields = qw/
      DESCRIPTION
      DESIGNATION
      NAME
      STATUS
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'SLOTS',
        'values' => $args,
        });
}
# For compatibiliy
sub addSlots {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addSlots to addSlot()");
   $self->addSlot(@_);
}

=item addSoftware()

Register a software in the inventory.

=cut
sub addSoftware {
  my ($self, $args) = @_;

  my @fields = qw/COMMENTS FILESIZE FOLDER FROM HELPLINK INSTALLDATE NAME
NO_REMOVE RELEASE_TYPE PUBLISHER UNINSTALL_STRING URL_INFO_ABOUT VERSION
VERSION_MINOR VERSION_MAJOR IS64BIT GUID/;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'SOFTWARES',
        'values' => $args,
        'noDuplicated' => 1
        });
}
# For compatibiliy
sub addSoftwares {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addSoftwares to addSoftware()");
   $self->addSoftware(@_);
}

=item addMonitor()

Add a monitor (screen) in the inventory.

=cut
sub addMonitor {
  my ($self, $args) = @_;

  my @fields = qw/
      BASE64
      CAPTION
      DESCRIPTION
      MANUFACTURER
      SERIAL
      UUENCODE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'MONITORS',
        'values' => $args,
        });
}
# For compatibiliy
sub addMonitors {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addMonitors to addMonitor()");
   $self->addMonitor(@_);
}

=item addVideo()

Add a video card in the inventory.

=cut
sub addVideo {
  my ($self, $args) = @_;

  my @fields = qw/
      CHIPSET
      MEMORY
      NAME
      RESOLUTION
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'VIDEOS',
        'values' => $args,
        'noDuplicated' => 1
        });

}
# For compatibiliy
sub addVideos {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addVideos to addVideo()");
   $self->addVideo(@_);
}

=item addSound()

Add a sound card in the inventory.

=cut
sub addSound {
  my ($self, $args) = @_;

  my @fields = qw/
      DESCRIPTION
      MANUFACTURER
      NAME
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'SOUNDS',
        'values' => $args,
        });
}
# For compatibiliy
sub addSounds {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addSounds to addSound()");
   $self->addSound(@_);
}


=item addNetwork()

Register a network interface in the inventory.

=cut
sub addNetwork {
my ($self, $args) = @_;

    my @fields = qw/
        DESCRIPTION
        DRIVER
        IPADDRESS
        IPADDRESS6
        IPDHCP
        IPGATEWAY
        IPMASK
        IPSUBNET
        MACADDR
        MTU
        PCISLOT
        STATUS
        TYPE
        VIRTUALDEV
        SLAVES
        SPEED
        MANAGEMENT
        /;


  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'NETWORKS',
        'values' => $args,
        'noDuplicated' => 1
        });
}

# For compatibiliy
sub addNetworks {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addNetworks to addNetwork()");
   $self->addNetwork(@_);
}


=item setHardware()

Save global information regarding the machine.

The use of setHardware() to update USERID and PROCESSOR* informations is
deprecated, please, use addUser() and addCPU() instead.

=cut
sub setHardware {
  my ($self, $args, $nonDeprecated) = @_;

  my $logger = $self->{logger};

  foreach my $key (qw/USERID OSVERSION PROCESSORN OSCOMMENTS CHECKSUM
    PROCESSORT NAME PROCESSORS SWAP ETIME TYPE OSNAME IPADDR WORKGROUP
    DESCRIPTION MEMORY UUID DNS LASTLOGGEDUSER USERDOMAIN
    DATELASTLOGGEDUSER DEFAULTGATEWAY VMSYSTEM WINOWNER WINPRODID
    WINPRODKEY WINCOMPANY WINLANG/) {
# WINLANG: Windows Language, see MSDN Win32_OperatingSystem documentation
    if (exists $args->{$key}) {
      if ($key eq 'PROCESSORS' && !$nonDeprecated) {
          $logger->debug("PROCESSORN, PROCESSORS and PROCESSORT shouldn't be set directly anymore. Please use addCPU() method instead.");
      }
      if ($key eq 'USERID' && !$nonDeprecated) {
          $logger->debug("USERID shouldn't be set directly anymore. Please use addCPU() method instead.");
      }

      my $string = $self->_encode({ string => $args->{$key} });
      $self->{h}{'CONTENT'}{'HARDWARE'}{$key}[0] = $string;
    }
  }
}

=item setBios()

Set BIOS informations.

=cut
sub setBios {
  my ($self, $args) = @_;

  foreach my $key (qw/SMODEL SMANUFACTURER SSN BDATE BVERSION BMANUFACTURER
      MMANUFACTURER MSN MMODEL ASSETTAG ENCLOSURESERIAL BASEBOARDSERIAL
      BIOSSERIAL/) {

    if (exists $args->{$key}) {
      my $string = $self->_encode({ string => $args->{$key} });
      $self->{h}{'CONTENT'}{'BIOS'}{$key}[0] = $string;
    }
  }
}

=item addCPU()

Add a CPU in the inventory.

=cut
sub addCPU {
  my ($self, $args) = @_;

  my @fields = qw/
      CACHE
      CORE
      DESCRIPTION
      MANUFACTURER
      NAME
      THREAD
      SERIAL
      SPEED
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'CPUS',
        'values' => $args,
        'noDuplicated' => 1
        });

  # For the compatibility with HARDWARE/PROCESSOR*
  my $processorn = int @{$self->{h}{CONTENT}{CPUS}};
  my $processors = $self->{h}{CONTENT}{CPUS}[0]{SPEED}[0];
  my $processort = $self->{h}{CONTENT}{CPUS}[0]{NAME}[0];

  $self->setHardware ({
    PROCESSORN => $processorn,
    PROCESSORS => $processors,
    PROCESSORT => $processort,
  }, 1);

}

=item addUser()

Add an user in the list of logged user.

=cut
sub addUser {
  my ($self, $args) = @_;

  my @fields = qw/
      LOGIN
      DOMAIN
      /;

  my $values = $args;
  return unless $values->{login};

  $self->_addEntry({
         'field' => \@fields,
        'sectionName' => 'USERS',
        'values' => $args,
        'noDuplicated' => 1
        });


# Compare with old system 
  my $userString = $self->{h}{CONTENT}{HARDWARE}{USERID}[0] || "";
  my $domainString = $self->{h}{CONTENT}{HARDWARE}{USERDOMAIN}[0] || "";

  $userString .= '/' if $userString;
  $domainString .= '/' if $domainString;

  my $login = $args->{LOGIN}; 
  my $domain = $args->{DOMAIN}; 
# TODO: I don't think we should change the parmater this way. 
  if ($login =~ /(.*\\|)(\S+)/) {
      $domainString .= $domain;
      $userString .= $2;
  } else {
      $domainString .= $domain;
      $userString .= $login;
  }


  $self->setHardware ({
          USERID => $userString,
          USERDOMAIN => $domainString,
  }, 1);


}

=item addPrinter()

Add a printer in the inventory.

=cut
sub addPrinter {
  my ($self, $args) = @_;

  my @fields = qw/
      COMMENT
      DESCRIPTION
      DRIVER
      NAME
      NETWORK
      PORT
      RESOLUTION
      SHARED
      STATUS
      ERRSTATUS
      SERVERNAME
      SHARENAME
      PRINTPROCESSOR
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'PRINTERS',
        'values' => $args,
        });
}
# For compatibiliy
sub addPrinters {
   my $self = shift;
   my $logger = $self->{logger};

   $logger->debug("please rename addPrinters to addPrinter()");
   $self->addPrinter(@_);
}

=item addVirtualMachine()

Add a Virtual Machine in the inventory.

=cut
sub addVirtualMachine {
  my ($self, $args) = @_;

  my $logger = $self->{logger};

  my @fields = qw/
      logger
      MEMORY
      NAME
      UUID
      STATUS
      SUBSYSTEM
      VMTYPE
      VCPU
      VMID
      /;

  if (!$args->{status}) {
      $logger->error("status not set by ".caller(0));
  } elsif (!$args->{status} =~ /(running|idle|paused|shutdown|crashed|dying|off)/) {
    $logger->error("Unknown status '".$args->{status}."' from ".caller(0));
  }

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'VIRTUALMACHINES',
        'values' => $args,
        });

}

=item addProcess()

Record a running process in the inventory.

=cut
sub addProcess {
  my ($self, $args) = @_;

  my @fields = qw/
      USER
      PID
      CPUUSAGE
      MEM
      VIRTUALMEMORY
      TTY
      STARTED
      CMD
      /;


  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'PROCESSES',
        'values' => $args,
        });
}

=item addInput()

Add an input device (mouce/keyboard) in the inventory.

=cut
sub addInput {
  my ($self, $args) = @_;

  my @fields = qw/
      CAPTION
      DESCRIPTION
      INTERFACE
      LAYOUT
      POINTTYPE
      TYPE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'INPUTS',
        'values' => $args,
        });
}

=item addEnv()

Register an environement variable.

=cut
sub addEnv {
  my ($self, $args) = @_;

  my @fields = qw/
      KEY
      VAL
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'ENVS',
        'values' => $args,
        });
}

=item addUpdate()

Windows Update

=cut
sub addUpdate {
  my ($self, $args) = @_;

  my $id = $args->{ID};
  my $kb = $args->{KB};

  push @{$self->{h}{CONTENT}{UPDATES}},
  {

    ID => [$id?$id:''],
    KB => [$kb?$kb:''],

  };
}

=item addUSBDevice()

USB device

=cut
sub addUSBDevice {
  my ($self, $args) = @_;

  my @fields = qw/VENDORID PRODUCTID SERIAL/;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'USBDEVICES',
        'values' => $args,
        'noDuplicated' => 1
        });
}

=item addBattery()

Battery

=cut
sub addBattery {
  my ($self, $args) = @_;

  my @fields = qw/
      CAPACITY
      CHEMISTRY
      DATE
      NAME
      SERIAL
      MANUFACTURER
      VOLTAGE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'BATTERIES',
        'values' => $args,
        });
}



=item addRegistry()

USB device

=cut
sub addRegistry {
  my ($self, $args) = @_;

  my @fields = qw/
      NAME
      REGVALUE
      HIVE
      /;

  $self->_addEntry({
        'field' => \@fields,
        'sectionName' => 'REGISTRY',
        'values' => $args,
        });
}




=item setAccessLog()

What is that for? :)

=cut
sub setAccessLog {
  my ($self, $args) = @_;

  foreach my $key (qw/USERID LOGDATE/) {

    if (exists $args->{$key}) {
      $self->{h}{'CONTENT'}{'ACCESSLOG'}{$key}[0] = $args->{$key};
    }
  }
}

=item addIpDiscoverEntry()

IpDiscover is used to identify network interface on the local network. This
is done on the ARP level.

This function adds a network interface in the inventory.

=cut
sub addIpDiscoverEntry {
  my ($self, $args) = @_;

  my $ipaddress = $args->{IPADDRESS};
  my $macaddr = $args->{MACADDR};
  my $name = $args->{NAME};

  if (!$self->{h}{CONTENT}{IPDISCOVER}{H}) {
    $self->{h}{CONTENT}{IPDISCOVER}{H} = [];
  }

  push @{$self->{h}{CONTENT}{IPDISCOVER}{H}}, {
    # If I or M is undef, the server will ingore the host
    I => [$ipaddress?$ipaddress:""],
    M => [$macaddr?$macaddr:""],
    N => [$name?$name:"-"], # '-' is the default value reteurned by ipdiscover
  };
}

=item addSoftwareDeploymentPackage()

This function is for software deployment.

Order sent to the agent are recorded on the client side and then send back
to the server in the inventory.

=cut
sub addSoftwareDeploymentPackage {
  my ($self, $args) = @_;

  my $orderId = $args->{ORDERID};

  # For software deployment
  if (!$self->{h}{CONTENT}{DOWNLOAD}{HISTORY}) {
      $self->{h}{CONTENT}{DOWNLOAD}{HISTORY} = [];
  }

  push (@{$self->{h}{CONTENT}{DOWNLOAD}{HISTORY}->[0]{PACKAGE}}, { ID =>
          $orderId });
}

=item getContent()

Return the inventory as a XML string.

=cut
sub getContent {
  my ($self, $args) = @_;

  my $logger = $self->{logger};

  $self->initialise();

  $self->processChecksum();

  #  checks for MAC, NAME and SSN presence
  my $macaddr = $self->{h}->{CONTENT}->{NETWORKS}->[0]->{MACADDR}->[0];
  my $ssn = $self->{h}->{CONTENT}->{BIOS}->{SSN}->[0];
  my $name = $self->{h}->{CONTENT}->{HARDWARE}->{NAME}->[0];

  my $missing;

  $missing .= "MAC-address " unless $macaddr;
  $missing .= "SSN " unless $ssn;
  $missing .= "HOSTNAME " unless $name;

  if ($missing) {
    $logger->debug('Missing value(s): '.$missing.'. I will send this inventory to the server BUT important value(s) to identify the computer are missing');
  }

  my $content = XMLout( $self->{h}, RootName => 'REQUEST', XMLDecl => '<?xml version="1.0" encoding="UTF-8"?>', SuppressEmpty => undef );

  return $content;
}

=item printXML()

Only for debugging purpose. Print the inventory on STDOUT.

=cut
sub printXML {
  my ($self, $args) = @_;

  $self->initialise();
  print $self->getContent();
}

=item writeXML()

Save the generated inventory as an XML file. The 'local' key of the config
is used to know where the file as to be saved.

=cut
sub writeXML {
  my ($self, $args) = @_;

  my $logger = $self->{logger};
  my $config = $self->{config};
  my $target = $self->{target};

  if ($target->{path} =~ /^$/) {
    $logger->fault ('local path unititalised!');
  }

  $self->initialise();

  my $localfile = $config->{local}."/".$target->{deviceid}.'.ocs';
  $localfile =~ s!(//){1,}!/!;

  # Convert perl data structure into xml strings

  if (open OUT, ">$localfile") {
    print OUT $self->getContent();
    close OUT or warn;
    $logger->info("Inventory saved in $localfile");
  } else {
    warn "Can't open `$localfile': $!"
  }
}

=item processChecksum()

Compute the <CHECKSUM/> field. This information is used by the server to
know which parts of the XML have changed since the last inventory.

The is done thank to the last_file file. It has MD5 prints of the previous
inventory. 

=cut
sub processChecksum {
  my $self = shift;

  my $logger = $self->{logger};
  my $target = $self->{target};

#To apply to $checksum with an OR
  my %mask = (
    'HARDWARE'      => 1,
    'BIOS'          => 2,
    'MEMORIES'      => 4,
    'SLOTS'         => 8,
    'REGISTRY'      => 16,
    'CONTROLLERS'   => 32,
    'MONITORS'      => 64,
    'PORTS'         => 128,
    'STORAGES'      => 256,
    'DRIVES'        => 512,
    'INPUT'         => 1024,
    'MODEMS'        => 2048,
    'NETWORKS'      => 4096,
    'PRINTERS'      => 8192,
    'SOUNDS'        => 16384,
    'VIDEOS'        => 32768,
    'SOFTWARES'     => 65536,
    'VIRTUALMACHINES' => 131072,
  );
  # TODO CPUS is not in the list

  if (!$self->{target}->{vardir}) {
    $logger->fault ("vardir uninitialised!");
  }

  my $checksum = 0;

  if ($target->{last_statefile}) {
    if (-f $target->{last_statefile}) {
      # TODO: avoid a violant death in case of problem with XML
      $self->{last_state_content} = XML::Simple::XMLin(

        $target->{last_statefile},
        SuppressEmpty => undef,
        ForceArray => 1

      );
    } else {
      $logger->debug ('last_state file: `'.
      $target->{last_statefile}.
        "' doesn't exist (yet).");
    }
  }

  foreach my $section (keys %mask) {
    #If the checksum has changed...
    my $hash =
        md5_base64(XML::Simple::XMLout($self->{h}{'CONTENT'}{$section}));
    if (!$self->{last_state_content}->{$section}[0] || $self->{last_state_content}->{$section}[0] ne $hash ) {
      $logger->debug ("Section $section has changed since last inventory");
      #We make OR on $checksum with the mask of the current section
      $checksum |= $mask{$section};
    }
    # Finally I store the new value.
    $self->{last_state_content}->{$section}[0] = $hash;
  }


  $self->setHardware({CHECKSUM => $checksum});
}

=item saveLastState()

At the end of the process IF the inventory was saved
correctly, the last_state is saved.

=cut
sub saveLastState {
  my ($self, $args) = @_;

  my $logger = $self->{logger};
  my $target = $self->{target};

  if (!defined($self->{last_state_content})) {
	  $self->processChecksum();
  }

  if (!defined ($target->{last_statefile})) {
    $logger->debug ("Can't save the last_state file. File path is not initialised.");
    return;
  }

  if (open LAST_STATE, ">".$target->{last_statefile}) {
    print LAST_STATE my $string = XML::Simple::XMLout( $self->{last_state_content}, RootName => 'LAST_STATE' );;
    close LAST_STATE or warn;
  } else {
    $logger->debug ("Cannot save the checksum values in ".$target->{last_statefile}."
	(will be synchronized by GLPI!!): $!");
  }
}

=item addSection()

A generic way to save a section in the inventory. Please avoid this
solution.

=cut
sub addSection {
  my ($self, $args) = @_;
  my $logger = $self->{logger};
  my $multi = $args->{multi};
  my $tagname = $args->{tagname};

  $logger->debug("Please, don't use addSection(). This function may be ".
      "dropped in the future.");

  for( keys %{$self->{h}{CONTENT}} ){
    if( $tagname eq $_ ){
      $logger->debug("Tag name `$tagname` already exists - Don't add it");
      return 0;
    }
  }

  if($multi){
    $self->{h}{CONTENT}{$tagname} = [];
  }
  else{
    $self->{h}{CONTENT}{$tagname} = {};
  }
  return 1;
}

=item feedSection()

Add information in inventory.

=back
=cut
# Q: is that really useful()? Can't we merge with addSection()?
sub feedSection{
  my ($self, $args) = @_;
  my $tagname = $args->{tagname};
  my $values = $args->{data};
  my $logger = $self->{logger};

  my $found=0;
  for( keys %{$self->{h}{CONTENT}} ){
    $found = 1 if $tagname eq $_;
  }

  if(!$found){
    $logger->debug("Tag name `$tagname` doesn't exist - Cannot feed it");
    return 0;
  }

  if( $self->{h}{CONTENT}{$tagname} =~ /ARRAY/ ){
    push @{$self->{h}{CONTENT}{$tagname}}, $args->{data};
  }
  else{
    $self->{h}{CONTENT}{$tagname} = $values;
  }

  return 1;
}

1;
=head1 XML STRUCTURE

This section presents the XML structure used by FusionInventory. The schema
is based on OCS Inventory XML with various additions.

=head2 BIOS

=over 4

=item SMODEL

=item SMANUFACTURER

=item SSN

=item BDATE

=item BVERSION

The BIOS revision

=item BMANUFACTURER

=item MMANUFACTURER

=item MSN

=item MMODEL

=item ASSETTAG

=item ENCLOSURESERIAL

=item BASEBOARDSERIAL

=item BIOSSERIAL

The optional asset tag for this machine.

=back

=head2 CONTROLLERS

=over 4

=item DRIVER

=item NAME

=item MANUFACTURER

=item PCICLASS

=item PCIID

The PCI ID, e.g: 8086:2a40 (only for PCI device)

=item PCISUBSYSTEMID

The PCI subsystem ID, e.g: 8086:2a40 (only for PCI device)

=item PCISLOT

The PCI slot, e.g: 00:02.1 (only for PCI device)

=item TYPE

The controller revision, e.g: rev 02. This field may be renamed
in the future.

=back

=head2 MEMORIES

=over 4

=item CAPACITY

=item CAPTION

E.g: Physical Memory

=item DESCRIPTION

=item FORMFACTOR

Only avalaible on Windows, See Win32_PhysicalMemory documentation on MSDN.

=item REMOVABLE

=item PURPOSE

Only avalaible on Windows, See Win32_PhysicalMemory documentation on MSDN.

=item SPEED

In Mhz, e.g: 800

=item TYPE

=item NUMSLOTS

Eg. 2, start at 1, not 0

=item SERIALNUMBER

=back

=head2 CPUS

=over 4

=item CACHESIZE

The total CPU cache size in KB. e.g: 3072

=item CORE

Number of core.

=item DESCRIPTION

=item MANUFACTURER

=item NAME

The name of the CPU, e.g: Intel(R) Core(TM)2 Duo CPU     P8600  @ 2.40GHz

=item THREAD

Number of thread.

=item SERIAL

CPU Id/Serial

=item SPEED

Frequency in MHz

=back

=head2 DRIVES

Drive is actually a filesystem.

=over 4

=item CREATEDATE

Date of the create of the filesystem in in DD/MM/YYYY format.

=item DESCRIPTION

=item FREE

=item FILESYSTEM

=item LABEL

=item LETTER

Windows driver letter. Windows only

=item SERIAL

Partition serial number

=item SYSTEMDRIVE

Boolean. Is the system partition?

=item TOTAL

Total space avalaible.

=item TYPE

=item VOLUMN

Name of the partition.

=back

=head2 HARDWARE

=over 4

=item USERID

The current user list, '/' is the delemiter. This field is deprecated, you
should use the USERS section instead.

=item OSVERSION

=item PROCESSORN

=item OSCOMMENTS

Service Pack on Windows, kernel build date on Linux

=item CHECKSUM

Deprecated, OCS only.

=item PROCESSORT

=item NAME

=item PROCESSORS

The processor speed in MHz, this field is deprecated, see CPUS instead.

=item SWAP

The swap space in MB.

=item ETIME

The time needed to run the inventory on the agent side.

=item TYPE

=item OSNAME

=item IPADDR

=item WORKGROUP

=item DESCRIPTION

=item MEMORY

=item UUID

=item DNS

=item LASTLOGGEDUSER

The login of the last logged user.

=item USERDOMAIN

This field is deprecated, you should use the USERS section instead.

=item DATELASTLOGGEDUSER

=item DEFAULTGATEWAY

=item VMSYSTEM

The virtualization technologie used if the machine is a virtual machine.

Can by: Physical (default), Xen, VirtualBox, Virtual Machine, VMware, QEMU, SolarisZone

=item WINOWNER

=item WINPRODID

=item WINPRODKEY

=item WINCOMPANY

=item WINLANG

=back

=head2 MONITORS

=over 4

=item BASE64

The uuencoded EDID trame. Optional.

=item CAPTION

=item DESCRIPTION

=item MANUFACTURER

The manufacturer retrieved from the EDID trame.

=item SERIAL

The serial number retrieved from the EDID trame.

=item UUENCODE

The uuencoded EDID trame. Optional.

=back

=head2 PORTS

Serial, Parallel, SATA, etc

=over 4

=item CAPTION

=item DESCRIPTION

=item NAME

=item TYPE

=back

=head2 SLOTS

=over 4

=item CAPACITY

=item CAPTION

=item FORMFACTOR

=item REMOVABLE

=item PURPOSE

=item TYPE

=item DESCRIPTION

=back

=head2 STORAGES

=over 4

=item DESCRIPTION

=item DISKSIZE

The disk size in MB.

=item INTERFACE

=item MANUFACTURER

=item MODEL

=item NAME

=item TYPE

INTERFACE can be SCSI/HDC/IDE/USB/1394
(See: Win32_DiskDrive / InterfaceType in MSDN documentation


=item SERIAL

The harddrive serial number

=item SERIALNUMBER

Deprecated. The harddrive serial number, same as SERIAL.

=item FIRMWARE

=item SCSI_COID

=item SCSI_CHID

=item SCSI_UNID

=item SCSI_LUN

=back

=head2 SOFTWARES

=over 4

=item COMMENTS

=item FILESIZE

=item FOLDER

=item FROM

Where the information about the software come from, can be:
registry, rpm, deb, etc

=item HELPLINK

=item INSTALLDATE

Installation day in DD/MM/YYYY format. Windows only.

=item NAME

=item NO_REMOVE

=item RELEASE_TYPE

Windows only for now, come from the registry

=item PUBLISHER

=item UNINSTALL_STRING

Windows only, come from the registry

=item URL_INFO_ABOUT

=item VERSION

=item VERSION_MINOR

Windows only, come from the registry

=item VERSION_MAJOR

Windows only, come from the registry

=item IS64BIT

If the software is in 32 or 64bit, (1/0)

=item GUID

Windows software GUID

=back

=head2 USERS

=over 4

=item LOGIN

=item DOMAIN

The Windows domain of the user, if avalaible.

=back

=head2 VIDEOS

=over 4

=item CHIPSET

=item MEMORY

=item NAME

=item RESOLUTION

Resolution in pixel. 1024x768.

=back

=head2 VIRTUALMACHINES

=over 4

=item MEMORY

Memory size, in MB.

=item NAME

The name of the virtual machine.

=item UUID

=item STATUS

The VM status: running, idle, paused, shutdown, crashed, dying, off

=item SUBSYSTEM

The virtualisation software.
E.g: VmWare ESX

=item VMTYPE

The name of the virtualisation system family, eg. Xen or VmWare.

=item VCPU

=item VMID

The ID of virtual machine in the virtual managment system.

=back

=head2 SOUNDS

=over 4

=item DESCRIPTION

=item MANUFACTURER

=item NAME

=back

=head2 MODEMS

=over 4

=item DESCRIPTION

=item NAME

=back

=head2 ENVS

Environement variables

=over 4

=item KEY

=item VAL

=back

=head2 UPDATES 

Windows updates

=over 4

=item ID 

Update Id

=item KB

List of KB, delimiter is '/'

=back

=head2 USBDEVICES 

USB Devices

=over 4

=item VENDORID 

Vendor USB ID. 4 hexa char.

=item PRODUCTID 

Product USB ID. 4 hexa char.

=item SERIAL

=item CLASS

USB Class (e.g: 8 for Mass Storage)

=item SUBCLASS

USB Sub Class

=back

=head2 NETWORKS

=over 4

=item DESCRIPTION

=item DRIVER

=item IPADDRESS

=item IPADDRESS6

=item IPDHCP

=item IPGATEWAY

=item IPMASK

=item IPSUBNET

=item MACADDR

=item MTU

=item PCISLOT

=item STATUS

=item TYPE

=item VIRTUALDEV

If the interface exist or not (1 or empty)

=item SLAVES

=item MANAGEMENT

Whether or not it is a HP iLO, Sun SC, HP MP or other kink of Remote Management Interface

=item SPEED

Interface speed in Mb/s

=back

=head2 BATTERIES

=over 4

=item CAPACITY

Battery capacity in mWh

=item DATE

Manufacture date in the DD/MM/YYYY format

=item NAME

Name of the device

=item SERIAL

Serial number

=item MANUFACTURER

Battery manufacturer

=item VOLTAGE

Voltage in mV

=back

=head2 PRINTERS

=over 4

=item COMMENT

=item DESCRIPTION

=item DRIVER

=item NAME

=item NETWORK

Network: True (1) if it's a network printer

=item PORT

=item RESOLUTION

Resolution: eg. 600x600

=item SHARED

Shared: True if the printer is shared (Win32)

=item STATUS

Status: See Win32_Printer.PrinterStatus

=item ERRSTATUS

ErrStatus: See Win32_Printer.ExtendedDetectedErrorState

=item SERVERNAME

=item SHARENAME

=item PRINTPROCESSOR

."=back
