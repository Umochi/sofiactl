#!/usr/bin/perl

#
# Simple clock synchronization for some chinese HiSilicon based DVRs supporting CMS (Sofia software) with json-like protocol. Tested with:
#
# HJCCTV HJ-H4808BW (XiongMai, Hi3520, MBD6304T)
# http://www.aliexpress.com/item/Hybird-NVR-8chs-H-264DVR-8chs-onvif-2-3-Economical-DVR-8ch-Video-4-AUDIO-AND/1918734952.html
#
#
# PBFZ TCV-UTH200 (XiongMai, Hi3518, 50H20L_S39)
# http://www.aliexpress.com/item/Free-shipping-2014-NEW-IP-camera-CCTV-2-0MP-HD-1080P-IP-Network-Security-CCTV-Waterproof/1958962188.html
#
# USAFEQLO USA-IPT-Y307/335 (XiongMai NRW4X-5274P-5X XM530_80X50_8M)
# http://www.aliexpress.com/item/4000078604009.html
#
# Additional protocol reference : https://github.com/charmyin/IPCTimeLapse
# vendor sdk: https://github.com/mondwan/cpp-surveillance-cli
# vendor: http://www.xiongmaitech.com
# vendor specifications: http://wiki.xm030.com:81/
# password hashing: https://github.com/tothi/pwn-hisilicon-dvr

package IPcam;
use Module::Load::Conditional qw[can_load check_install requires];
my $use_list = {
    'IO::Socket'       => undef,
    'IO::Socket::INET' => undef,
    'Time::Local'      => undef,
    JSON               => undef,
    'Data::Dumper'     => undef,
    'Digest::MD5'      => undef,
};

if ( !can_load( modules => $use_list, autoload => true ) ) {
    my @deps;
    for $module (keys %{$use_list}) {
        if (!check_install(module => $module)) {
           push(@deps, $module);
        }
    }

    print STDERR "Failed to load required modules. Try to install the missing dependencies manually by executing:\n\n \$ sudo cpan " . join( ' ', @deps) . "\n";
    exit(1);
}

use constant {
    LOGIN_REQ1      => 999,
    LOGIN_REQ2      => 1000,
    LOGIN_RSP       => 1000,
    LOGOUT_REQ      => 1001,
    LOGOUT_RSP      => 1002,
    FORCELOGOUT_REQ => 1003,
    FORCELOGOUT_RSP => 1004,
    KEEPALIVE_REQ   => 1006,    # 1005
    KEEPALIVE_RSP   => 1007,    # 1006

    SYSINFO_REQ => 1020,
    SYSINFO_RSP => 1021,

    CONFIG_SET                     => 1040,
    CONFIG_SET_RSP                 => 1041,
    CONFIG_GET                     => 1042,
    CONFIG_GET_RSP                 => 1043,
    DEFAULT_CONFIG_GET             => 1044,
    DEFAULT_CONFIG_GET_RSP         => 1045,
    CONFIG_CHANNELTILE_SET         => 1046,
    CONFIG_CHANNELTILE_SET_RSP     => 1047,
    CONFIG_CHANNELTILE_GET         => 1048,
    CONFIG_CHANNELTILE_GET_RSP     => 1049,
    CONFIG_CHANNELTILE_DOT_SET     => 1050,
    CONFIG_CHANNELTILE_DOT_SET_RSP => 1051,

    SYSTEM_DEBUG_REQ => 1052,
    SYSTEM_DEBUG_RSP => 1053,

    ABILITY_GET     => 1360,
    ABILITY_GET_RSP => 1361,

    PTZ_REQ => 1400,
    PTZ_RSP => 1401,

    MONITOR_REQ       => 1410,
    MONITOR_RSP       => 1411,
    MONITOR_DATA      => 1412,
    MONITOR_CLAIM     => 1413,
    MONITOR_CLAIM_RSP => 1414,

    PLAY_REQ       => 1420,
    PLAY_RSP       => 1421,
    PLAY_DATA      => 1422,
    PLAY_EOF       => 1423,
    PLAY_CLAIM     => 1424,
    PLAY_CLAIM_RSP => 1425,
    DOWNLOAD_DATA  => 1426,

    TALK_REQ        => 1430,
    TALK_RSP        => 1431,
    TALK_CU_PU_DATA => 1432,
    TALK_PU_CU_DATA => 1433,
    TALK_CLAIM      => 1434,
    TALK_CLAIM_RSP  => 1435,

    FILESEARCH_REQ        => 1440,
    FILESEARCH_RSP        => 1441,
    LOGSEARCH_REQ         => 1442,
    LOGSEARCH_RSP         => 1443,
    FILESEARCH_BYTIME_REQ => 1444,
    FILESEARCH_BYTIME_RSP => 1445,

    SYSMANAGER_REQ => 1450,
    SYSMANAGER_RSP => 1451,
    TIMEQUERY_REQ  => 1452,
    TIMEQUERY_RSP  => 1453,

    DISKMANAGER_REQ => 1460,
    DISKMANAGER_RSP => 1461,

    FULLAUTHORITYLIST_GET     => 1470,
    FULLAUTHORITYLIST_GET_RSP => 1471,
    USERS_GET                 => 1472,
    USERS_GET_RSP             => 1473,
    GROUPS_GET                => 1474,
    GROUPS_GET_RSP            => 1475,
    ADDGROUP_REQ              => 1476,
    ADDGROUP_RSP              => 1477,
    MODIFYGROUP_REQ           => 1478,
    MODIFYGROUP_RSP           => 1479,
    DELETEGROUP_REQ           => 1480,
    DELETEGROUP_RSP           => 1481,
    ADDUSER_REQ               => 1482,
    ADDUSER_RSP               => 1483,
    MODIFYUSER_REQ            => 1484,
    MODIFYUSER_RSP            => 1485,
    DELETEUSER_REQ            => 1486,
    DELETEUSER_RSP            => 1487,
    MODIFYPASSWORD_REQ        => 1488,
    MODIFYPASSWORD_RSP        => 1489,

    GUARD_REQ           => 1500,
    GUARD_RSP           => 1501,
    UNGUARD_REQ         => 1502,
    UNGUARD_RSP         => 1503,
    ALARM_REQ           => 1504,
    ALARM_RSP           => 1505,
    NET_ALARM_REQ       => 1506,
    NET_ALARM_REQ       => 1507,
    ALARMCENTER_MSG_REQ => 1508,

    UPGRADE_REQ      => 1520,
    UPGRADE_RSP      => 1521,
    UPGRADE_DATA     => 1522,
    UPGRADE_DATA_RSP => 1523,
    UPGRADE_PROGRESS => 1524,
    UPGRADE_INFO_REQ => 1525,
    UPGRADE_INFO_RSQ => 1526,

    IPSEARCH_REQ => 1530,
    IPSEARCH_RSP => 1531,
    IP_SET_REQ   => 1532,
    IP_SET_RSP   => 1533,

    CONFIG_IMPORT_REQ => 1540,
    CONFIG_IMPORT_RSP => 1541,
    CONFIG_EXPORT_REQ => 1542,
    CONFIG_EXPORT_RSP => 1543,
    LOG_EXPORT_REQ    => 1544,    #CONDIG_EXPORT_REQ
    LOG_EXPORT_RSP    => 1545,    #CONFIG_EXPORT_RSP

    NET_KEYBOARD_REQ => 1550,
    NET_KEYBOARD_RSP => 1551,

    NET_SNAP_REQ   => 1560,
    NET_SNAP_RSP   => 1561,
    SET_IFRAME_REQ => 1562,
    SET_IFRAME_RSP => 1563,

    RS232_READ_REQ             => 1570,
    RS232_READ_RSP             => 1571,
    RS232_WRITE_REQ            => 1572,
    RS232_WRITE_RSP            => 1573,
    RS485_READ_REQ             => 1574,
    RS485_READ_RSP             => 1575,
    RS485_WRITE_REQ            => 1576,
    RS485_WRITE_RSP            => 1577,
    TRANSPARENT_COMM_REQ       => 1578,
    TRANSPARENT_COMM_RSP       => 1579,
    RS485_TRANSPARENT_DATA_REQ => 1580,
    RS485_TRANSPARENT_DATA_RSP => 1581,
    RS232_TRANSPARENT_DATA_REQ => 1582,
    RS232_TRANSPARENT_DATA_RSP => 1583,

    SYNC_TIME_REQ => 1590,
    SYNC_TIME_RSP => 1591,

    PHOTO_GET_REQ => 1600,
    PHOTO_GET_RSP => 1601,

};

%error_codes = (
    100 => "OK",
    101 => "unknown mistake",
    102 => "Version not supported",
    103 => "Illegal request",
    104 => "The user has logged in",
    105 => "The user is not logged in",
    106 => "username or password is wrong",
    107 => "No permission",
    108 => "time out",
    109 => "Failed to find, no corresponding file found",
    110 => "Find successful, return all files",
    111 => "Find success, return some files",
    112 => "This user already exists",
    113 => "this user does not exist",
    114 => "This user group already exists",
    115 => "This user group does not exist",
    116 => "Error 116",
    117 => "Wrong message format",
    118 => "PTZ protocol not set",
    119 => "No query to file",
    120 => "Configure to enable",
    121 => "MEDIA_CHN_NOT CONNECT digital channel is not connected",
    150 => "Successful, the device needs to be restarted",
    202 => "User not logged in",
    203 => "The password is incorrect",
    204 => "User illegal",
    205 => "User is locked",
    206 => "User is on the blacklist",
    207 => "Username is already logged in",
    208 => "Input is illegal",
    209 => "The index is repeated if the user to be added already exists, etc.",
    210 => "No object exists, used when querying",
    211 => "Object does not exist",
    212 => "Account is in use",
    213 =>
"The subset is out of scope (such as the group's permissions exceed the permission table, the user permissions exceed the group's permission range, etc.)",
    214 => "The password is illegal",
    215 => "Passwords do not match",
    216 => "Retain account",
    502 => "The command is illegal",
    503 => "Intercom has been turned on",
    504 => "Intercom is not turned on",
    511 => "Already started upgrading",
    512 => "Not starting upgrade",
    513 => "Upgrade data error",
    514 => "upgrade unsuccessful",
    515 => "update successed",
    521 => "Restore default failed",
    522 => "Need to restart the device",
    523 => "Illegal default configuration",
    602 => "Need to restart the app",
    603 => "Need to restart the system",
    604 => "Error writing a file",
    605 => "Feature not supported",
    606 => "verification failed",
    607 => "Configuration does not exist",
    608 => "Configuration parsing error",
);

sub new {
    my $classname = shift;
    my $self      = {};
    bless( $self, $classname );
    $self->_init(@_);
    return $self;
}

sub DESTROY {
    my $self = shift;
}

sub disconnect {
    my $self = shift;
    $self->{socket}->close();
}

sub _init {
    my $self = shift;
    $self->{host}        = "";
    $self->{port}        = 0;
    $self->{user}        = "";
    $self->{password}    = "";
    $self->{socket}      = undef;
    $self->{sid}         = 0;
    $self->{sequence}    = 0;
    $self->{SystemInfo}  = undef;
    $self->{GenericInfo} = undef;
    $self->{lastcommand} = undef;
    $self->{hashtype}    = 'md5based';
    $self->{debug}       = 0;
    $self->{channel}     = 0;
    $self->{begin_time}  = '';
    $self->{end_time}    = '';
    $self->{raw_data}    = '';

    if (@_) {
        my %extra = @_;
        @$self{ keys %extra } = values %extra;
    }

}

sub getDeviceRuntime {
    my $self = shift;

    $self->getSystemInfo();

    my $total_minutes = hex( $self->{SystemInfo}->{DeviceRunTime} );
    my $total_hours   = $total_minutes / 60;
    my $total_days    = $total_minutes / ( 60 * 24 );
    my $left_minutes  = $total_minutes % ( 60 * 24 );
    my $hours         = int( $left_minutes / 60 );
    my $minutes       = int( $left_minutes % 60 );
    my $years         = $total_days / 365;
    my $left_days     = $total_days % 365;
    my $months        = int( $left_days / 30 );
    my $days          = $left_days % 30;

    $total_minutes -= $months * 24 * 60;

    $total_hours = int($total_hours);
    $total_days  = int($total_days);

    $runtime = sprintf(
"%d day(s): %d year(s), %d month(s), %d day(s), %d hour(s), %d minute(s)",
        $total_days, $years, $months, $days, $hours, $minutes );

    return $runtime;
}

sub BuildPacketSid {
    my $self = shift;
    return $self->FormatHex( $self->{sid} );
}

sub FormatHex {
    my $self  = shift;
    my $value = $_[0];
    return sprintf( "0x%08x", $value );
}

sub BuildPacket {
    my $self = shift;
    my ( $type, $params ) = @_;

    my @pkt_prefix_1;
    my $pkt_type;
    my $json = JSON->new;

    @pkt_prefix_1 = ( 0xff, 0x00, 0x00, 0x00 )
      ;    # (head_flag, version (was 0x01), reserved01, reserved02)

    $pkt_type = $type;

    my $msgid = pack( 's', 0 ) . pack( 's', $pkt_type );

    my $pkt_prefix_data =
        pack( 'c*', @pkt_prefix_1 )
      . pack( 'i', $self->{sid} )
      . pack( 'i', $self->{sequence} )
      . $msgid;

#my $pkt_prefix_data =  pack('c*', @pkt_prefix_1) . pack('i', $self->{sid}) . pack('i', $pkt_prefix_2). $msgid;
    my $pkt_params_data = '';

    if ( $params ne undef ) {
        $pkt_params_data = $json->encode($params);
    }

    $pkt_params_data .= pack( 'C', 0x0a );

    my $pkt_data =
        $pkt_prefix_data
      . pack( 'i', length($pkt_params_data) )
      . $pkt_params_data;

    $self->{lastcommand} =
      $params->{Name} . sprintf( " msgid = %d", $pkt_type );
    $self->{sequence} += 1;

    return $pkt_data;

}

sub GetReplyHead {

    my $self = shift;

    my $data;

    my @reply_head_array;

    # head_flag, version, reserved
    $self->{socket}->recv( $data, 4 );

    my @header = unpack( 'C*', $data );

    my ( $head_flag, $version, $reserved01, $reserved02 ) =
      (@header)[ 0, 1, 2, 3 ];

    # int sid, int seq
    $self->{socket}->recv( $data, 8 );

    my ( $sid, $seq ) = unpack( 'i*', $data );

    $reply_head_array[3] = ();

    $self->{socket}->recv( $data, 8 );
    my ( $channel, $endflag, $msgid, $size ) = unpack( 'CCSI', $data );

    my $reply_head = {
        Version        => $version,
        SessionID      => $sid,
        Sequence       => $seq,
        MessageId      => $msgid,
        Content_Length => $size,
        Channel        => $channel,
        EndFlag        => $endflag,
    };

    $self->{sid} = $sid;

    #$self->{sequence} = $reply_head->{Sequence};

    if ( $self->{debug} ne 0 ) {
        printf(
"reply: head_flag=%x version=%d session=0x%x sequence=%d channel=%d end_flag=%d msgid=%d size = %d lastcommand = %s\n",
            $head_flag, $version, $sid,
            $seq,       $channel, $end_flag,
            $msgid,     $size,    $self->{lastcommand}
        );
    }
    return $reply_head;
}

sub GetReplyData {
    my $self = shift;

    my $reply = $_[0];

    my $length = $reply->{'Content_Length'};

    my $out;

    for ( my $downloaded = 0 ; $downloaded < $length ; $downloaded++ ) {
        $self->{socket}->recv( $data, 1 );
        $out .= $data;
    }

    #$out =~ s/\0+$//;

    return $out;
}

sub getSystemInfo {
    my $self = shift;

    if ( $self->{SystemInfo} eq undef ) {
        $self->CmdSystemInfo();
    }

    return $self->{SystemInfo};
}

sub VersionInfo {
    my $self = shift;

    my $versionstr = $_[0];

    $versionstr =~ /V(\d+)\.(\d{2})\.([A-Z][0-9]+)\.(\d{8})\.(\d{5})/;

    my $platform = {
        0 => "TI",
        1 => "Hisilicon 16M",
        2 => "Hisilicon 8M (S38)",
        3 => "TI (_S models)",
        4 => "Ambarella",
        5 => "Hisilicon 16M",
        6 => "Hisilicon 9M (Hi3518E)",
    };

    $ver = {
        major         => $1,
        minor         => int($2),
        release       => $3,
        oeminfo       => $4,
        build_options => $5,
    };

    $ver->{oeminfo} =~ /^(\d{3})(\d{2})(\d{3})/;

    $ver->{oem_manufacturer_id} = $1;
    $ver->{platform_id}         = int($2);
    $ver->{build_number}        = int($3);

    $ver->{build_options} =~ /^(\d)(\d)(\d)(\d)(\d)/;

    $ver->{cloud_service}            = $1;
    $ver->{basic_video_analytics}    = $2;
    $ver->{advanced_video_analytics} = $3;
    $ver->{onvif_server_ipc}         = $4;
    $ver->{onvif_client_nvr}         = $5;

    my $platform_id = $ver->{platform_id};

    $ver->{platform} = $platform->{$platform_id};

    return %$ver;
}

sub PrepareGenericCommandHead {

    my $self       = shift;
    my $msgid      = $_[0];
    my $parameters = $_[1];
    my $disc = $_[2];
    my $data;

    my $pkt = $parameters;

    if ( $msgid ne LOGIN_REQ2 and $parameters ne undef ) {
        $parameters->{SessionID} = $self->BuildPacketSid();
    }

    if ( $msgid eq MONITOR_REQ ) {
        $parameters->{SessionID} = sprintf( "0x%02X", $self->{sid} );
    }

    my $cmd_data = $self->BuildPacket( $msgid, $pkt );

    $self->{socket}->send($cmd_data);
    if($disc)
    {
        print "Force disconnecting\n";
        exit 0;
    }
    my $reply_head = $self->GetReplyHead();
    return $reply_head;
}

sub PrepareGenericCommand {
    my $self       = shift;
    my $msgid      = $_[0];
    my $parameters = $_[1];
    my $disc = $_[2];

    my $reply_head = $self->PrepareGenericCommandHead($msgid, $parameters, $disc);
    my $out = $self->GetReplyData($reply_head);

    if ($out) {
        $self->{raw_data} = $out;
        my $json;

		eval {
     		# code that might throw exception
			$json = decode_json($out);
		};
		if ($@) {
    		# report the exception and do something about it
			print "decode_json exception. data:" . $out ."\n";
		}



        my $code = $json->{'Ret'};

        if ( defined($code) ) {
            if ( defined( $error_codes{$code} ) ) {
                $json->{'RetMessage'} = $error_codes{$code};
            }
        }

        return $json;

    }

    return undef;
}

sub PrepareGenericStreamDownloadCommand {
    my $self       = shift;
    my $msgid      = $_[0];
    my $parameters = $_[1];
    my $file       = $_[2];
    my $size       = $_[3];

    my $reply_head = $self->PrepareGenericCommandHead( $msgid, $parameters );
    my $out = $self->GetReplyData($reply_head);

    if ($out) {
        $self->{raw_data} = $out;

        open( OUT, ">$file" );
        print OUT $out;
        close(OUT);

        return $out;

    }

    return undef;
}

sub WriteJSONDataToFile {
    my $self      = shift;
    my $filename  = $_[0];
    my $extension = $_[1];
    my $data      = $_[2];

    return 0 if ( $filename eq '' );

    if ( $filename !~ /\.$extension$/ ) {
        $filename .= ".$extension";
    }

    my $json = JSON->new;
    my $filedata;
    my $type = ref($data);

    if ( $type eq 'HASH' || $type eq 'ARRAY' ) {
        $filedata = $json->encode($data);
    }
    else {
        $filedata = $data;
    }

    open( OUT, "> $filename" );
    print OUT $filedata;
    close(OUT);
}

sub PrepareGenericDownloadCommand {
    my $self       = shift;
    my $msgid      = $_[0];
    my $parameters = $_[1];
    my $file       = $_[2];

    my $reply_head = $self->PrepareGenericCommandHead( $msgid, $parameters );
    my $out = $self->GetReplyData($reply_head);

    open( OUT, ">$file" );
    print OUT $out;
    close(OUT);

    return 1;
}

sub md5basedHash {
    my $self    = shift;
    my $message = $_[0];
    my $hash    = '';

    use Digest::MD5 qw(md5 md5_hex);

    my $msg_md5 = md5($message);

    if ( $self->{debug} ne 0 ) {
        print md5_hex($message) . "\n";
    }

    my @hash = unpack( 'C*', $msg_md5 );

    if ( $self->{debug} ne 0 ) {
        for my $chr (@hash) {
            print sprintf( "%02x ", $chr );
        }

        print "\n";
    }

    for ( my $i = 0 ; $i < 8 ; $i++ ) {
        my $n = ( $hash[ 2 * $i ] + $hash[ 2 * $i + 1 ] ) % 0x3e;

        if ( $n > 9 ) {
            if ( $n > 35 ) {
                $n += 61;
            }
            else {
                $n += 55;
            }
        }
        else {
            $n += 0x30;
        }

        if ( $self->{debug} ne 0 ) {
            print "$n\n";
        }

        $hash .= chr($n);
    }

    if ( $self->{debug} ne 0 ) {
        print "hash = $hash\n";
    }

    return $hash;
}

sub plainHash {
    my $self    = shift;
    my $message = $_[0];
    return $message;
}

sub MakeHash {
    my $self    = shift;
    my $message = $_[0];
    my $hash    = '';

    my $hashfunc = $self->{hashtype} . "Hash";

    return $hashfunc->( $self, $message );
}

sub ParseTimestamp {
    my $self      = shift;
    my $timestamp = $_[0];
    $timestamp =~ s/T/ /;
    $timestamp =~ s/Z//;
    return $timestamp;
}

sub CmdLogin {
    my $self = shift;

    my $data;
    my $pkt = {
        EncryptType => "MD5",
        LoginType   => "DVRIP-Web",
        PassWord    => $self->MakeHash( $self->{password} ),
        UserName    => $self->{user}

    };
    print Dumper $pkt;

    $reply_json = $self->PrepareGenericCommand( LOGIN_REQ2, $pkt );

    $self->{GenericInfo} = $reply_json;

    return $reply_json;
}

sub CmdSystemInfo {
    my $self = shift;

    my $pkt = { Name => 'SystemInfo', };

    my $systeminfo = $self->PrepareGenericCommand( SYSINFO_REQ, $pkt );
    $self->{SystemInfo} = $systeminfo->{SystemInfo};
    return $systeminfo;
}

sub CmdAlarmInfo {
    my $self       = shift;
    my $parameters = $_[0];

    my $pkt = {
        Name      => 'AlarmInfo',
        AlarmInfo => $parameters,
    };

    return $self->PrepareGenericCommand( ALARM_REQ, $pkt );
}

sub CmdOPNetAlarm {
    my $self = shift;

    my $pkt = {
        Name         => 'OPNetAlarm',
        NetAlarmInfo => {
            Event => 0,
            State => 1,
        },
    };

    return $self->PrepareGenericCommand( NET_ALARM_REQ, $pkt );
}

sub CmdAlarmCenterMsg {
    my $self = shift;
    my $data;

    my $pkt = {
        Name              => 'NetAlarmCenter',
        NetAlarmCenterMsg => {
            Address   => "0x0B0A060A",
            Channel   => 0,
            Descrip   => "",
            Event     => "MotionDetect",
            SerialID  => "003344236523",
            StartTime => "2010-06-24 17:04:22",
            Status    => "Stop",
            Type      => "Alarm",
        },
    };

    my $cmd_data = $self->BuildPacket( ALARMCENTER_MSG_REQ, $pkt );

    $self->{socket}->send($cmd_data);
    my $reply_head = $self->GetReplyHead();
    my $out        = $self->GetReplyData($reply_head);
    return decode_json($out);
}

sub CmdOPNetKeyboard {
    my $self       = shift;
    my $parameters = $_[0];

    my $pkt = {
        Name          => 'OPNetKeyboard',
        OPNetKeyboard => $parameters,
    };

    return $self->PrepareGenericCommand( NET_KEYBOARD_REQ, $pkt );
}

sub CmdUsers {
    my $self = shift;

    my $pkt = {

    };

    return $self->PrepareGenericCommand( USERS_GET, $pkt );
}

sub CmdGroups {
    my $self = shift;

    my $pkt = {

    };

    return $self->PrepareGenericCommand( GROUPS_GET, $pkt );
}

sub CmdStorageInfo {
    my $self = shift;

    my $pkt = { Name => 'StorageInfo', };

    return $self->PrepareGenericCommand( SYSINFO_REQ, $pkt );
}

sub CmdWorkState {
    my $self = shift;

    my $pkt = { Name => 'WorkState', };

    return $self->PrepareGenericCommand( SYSINFO_REQ, $pkt );
}

sub CmdSnap {
    my $self = shift;

    my $pkt = { Name => 'OPSNAP', };

    return $self->PrepareGenericCommand( NET_SNAP_REQ, $pkt );
}

sub CmdEmpty {
    my $self = shift;

    my $pkt = { Name => '', };

    return $self->PrepareGenericCommand( SYSINFO_REQ, $pkt );
}

sub CmdKeepAlive {
    my $self = shift;

    my $pkt = { Name => 'KeepAlive', };

    return $self->PrepareGenericCommand( KEEPALIVE_REQ, $pkt );
}

sub CmdOPMonitorClaim {
    my $self = shift;

    my $pkt = {
        Name      => 'OPMonitor',
        SessionID => $self->BuildPacketSid(),
        OPMonitor => {
            Action    => "Claim",
            Parameter => {
                Channel    => 0,
                CombinMode => "NONE",
                StreamType => "Extra1",
                TransMode  => "TCP"
            }
        }
    };

    my $cmd_data = $self->BuildPacket( MONITOR_CLAIM, $pkt );

    $self->{socket}->send($cmd_data);

    my $reply = $self->GetReplyHead();

    #for my $k (keys %{$reply}) {
    #  print "rh = $k\n";
    #}

    # my $out = $self->GetReplyData($reply);
    my $out1 = decode_json($reply);

    # $self->{socket}->recv($data, 1);

    return $out1;
}

sub CmdOPMonitorStop {
    my $self = shift;

    my $pkt = {
        Name      => 'OPMonitor',
        SessionID => $self->BuildPacketSid(),
        OPMonitor => {
            Action    => "Stop",
            Parameter => {
                Channel    => 0,
                CombinMode => "NONE",
                StreamType => "Extra1",
                TransMode  => "TCP"
            }
        }
    };

    my $cmd_data = $self->BuildPacket( MONITOR_REQ, $pkt );
    $self->{socket}->send($cmd_data);

    my $reply = $self->GetReplyHead();

    for my $k ( keys %{$reply} ) {
        print "rh = $k\n";
    }

    my $out  = $self->GetReplyData($reply);
    my $out1 = decode_json($out);

    # $self->{socket}->recv($data, 1);

    return $out1;
}

sub CmdOPMonitorStart {
    my $self = shift;
    my $data;

    my $pkt = {
        Name      => 'OPMonitor',
        SessionID => $self->BuildPacketSid(),
        OPMonitor => {
            Action    => "Start",
            Parameter => {
                Channel    => 0,
                CombinMode => "NONE",
                StreamType => "Extra1",
                TransMode  => "TCP"
            }
        }
    };

    my $cmd_data = $self->BuildPacket( MONITOR_REQ, $pkt );

    $self->{socket}->send($cmd_data);

    open( OUT, ">> " . $self->{sid} . ".h264" );

    $stop = 0;

    while ( defined( my $reply = $self->GetReplyHead() ) and $stop == 0 ) {
        if ( sprintf( "%x", $reply->{Data1} ) ne "12ff" ) {

            for my $k ( keys %{$reply} ) {
                print "rh = $k\n";
            }

            print "Content_Length = " . $reply->{Content_Length} . "\n";

            my $out = $self->GetReplyData($reply);
            print OUT $out;

            if ( $reply->{Sequence} > 3 ) {

                #$stop = 1;
                $self->CmdKeepAlive();
            }

        }
        else {
            $stop = 1;
            break;
        }

    }

    close(OUT);

    return $out1;
}

sub CmdOPTimeSetting {
    my $self  = shift;
    my $nortc = $_[0];
    my $data;

    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime();

    my $clock_cmd = 'OPTimeSetting';

    my $pkt_type = SYSMANAGER_REQ;

    if ( $nortc eq 1 ) {
        $clock_cmd .= 'NoRTC';
        $pkt_type = SYNC_TIME_REQ;
    }

    my $pkt = {
        Name         => $clock_cmd,
        SessionID    => $self->BuildPacketSid(),
        "$clock_cmd" => sprintf(
            "%4d-%02d-%02d %02d:%02d:%02d",
            $year + 1900,
            $mon + 1, $mday, $hour, $min, $sec
        )
    };

    my $cmd_data = $self->BuildPacket( $pkt_type, $pkt );

    $self->{socket}->send($cmd_data);
    my $reply = $self->GetReplyHead();
    my $out   = $self->GetReplyData($reply);

    if ($out) {
        return decode_json($out);
    }

    return undef;
}

#buggy
sub CmdSystemFunction {
    my $self = shift;

    my $pkt = { Name => 'SystemFunction', };

    return $self->PrepareGenericCommand( ABILITY_REQ, $pkt );
}

sub CmdOPFileQuery {
    my $self       = shift;
    my $parameters = $_[0];

    my $pkt = {
        Name        => 'OPFileQuery',
        OPFileQuery => $parameters,

    };

    return $self->PrepareGenericCommand( FILESEARCH_REQ, $pkt );
}

sub CmdOEMInfo {
    my $self = shift;

    my $pkt = { Name => 'OEMInfo', };

    return $self->PrepareGenericCommand( SYSINFO_REQ, $pkt );
}

sub CmdOPPlayBack {
    my $self       = shift;
    my $parameters = $_[0];
    my $file       = $_[1];

    my $pkt = {
        Name       => 'OPPlayBack',
        OPPlayBack => $parameters,
    };

    my $msgid = PLAY_REQ;

    if ( $parameters->{'Action'} eq 'Claim' ) {
        $msgid = PLAY_CLAIM;

   #return $self->PrepareGenericStreamDownloadCommand($msgid, $pkt, $file, 666);
    }

    if ( $parameters->{'Action'} eq 'DownloadStart' ) {
        return $self->PrepareGenericCommandHead( $msgid, $parameters );
    }

    return $self->PrepareGenericCommand( $msgid, $pkt );
}

sub CmdOPPlayBackDownloadStart {
    my $self       = shift;
    my $parameters = $_[0];
    my $flength    = $_[1];

    my $pkt = {
        Name       => 'OPPlayBack',
        OPPlayBack => $parameters,
    };

    my $fname = $parameters->{'Parameter'}->{'FileName'};
    $fname =~ s/^\///g;
    $fname =~ s/\//_/g;

	my $counter = 0;

    print "download fname: " . $fname . "\n";

	if ($counter == 0) {
		my $reply_head = $self->PrepareGenericCommandHead( PLAY_REQ, $pkt );
		my $container = $self->GetReplyData($reply_head);

    	open( OUT, "> $fname" );
    	print OUT $container;
    	

		$counter += $reply_head->{'Content_Length'};

		print "new counter = $counter\n";

		my $flag = 0;

		while ($flag == 0) {
			print "while counter\n";
			my $reply_head = $self->GetReplyHead();
			my $size = $reply_head->{'Content_Length'};
			if ($size > 0 && $reply_head->{'MessageId'} == DOWNLOAD_DATA) {
				my $data = $self->GetReplyData($reply_head);
				print OUT $data;
				$counter += $size;
			} else {
				$flag = 1;
			}

		}
		close(OUT);

	}

}

sub CmdOPLogQuery {
    my $self       = shift;
    my $parameters = $_[0];

    my $pkt = {
        Name => 'OPLogQuery',

        OPLogQuery => $parameters,
    };

    return $self->PrepareGenericCommand( LOGSEARCH_REQ, $pkt );
}

sub LogExport {
    my $self = shift;
    my $file = $_[0];

    my $pkt = { Name => '', };

    return $self->PrepareGenericDownloadCommand( LOG_EXPORT_REQ, $pkt, $file );
}

sub ConfigExport {
    my $self = shift;
    my $file = $_[0];

    my $pkt = { Name => '', };

    return $self->PrepareGenericDownloadCommand( CONFIG_EXPORT_REQ, $pkt,
        $file );
}

sub CmdOPStorageManager {
    my $self = shift;
    my $data;

    my $parameters = $_[0];

    my $pkt = {
        Name               => 'OPStorageManager',
        'OPStorageManager' => $parameters,
        SessionID          => $self->BuildPacketSid(),
    };

    return $self->PrepareGenericCommand( DISKMANAGER_REQ, $pkt );
}

sub CmdConfigGet {
    my $self       = shift;
    my $parameters = $_[0];

    my $pkt = { Name => $parameters, };

    return $self->PrepareGenericCommand( CONFIG_GET, $pkt );
}
sub CmdUpgrade {
    my $self       = shift;
	my $fw         = shift;
	my $udata="";
	my $pktSize=0x8000;
	my $blockNum=0;
	my $sentbytes=0;
	my $len=0;
	my $pkt="";
	my $reply_head;
	my $out;
	my $repl;
    my $json=JSON->new;
	
	STDOUT->autoflush(1);
	
	open( IN, "< $fw" ) or die("Failed to open firmware file\n");
   $decoded = $self->PrepareGenericCommand(IPcam::UPGRADE_REQ, {Name => "OPSystemUpgrade", OPSystemUpgrade => { Action => "Start", Type => "System" }});
   if($decoded->{Ret} != 100)
   {
    	print $error_codes{$decoded->{Ret}}."\n";
    	exit(1);
   }
	print "Uploading ".$fw."\n";
	while (1) {
		$len=read(IN,$udata,$pktSize);
		#print "len=".$len."\n";
		if($len == 0)
		{
			$pkt=pack("C",0xff).pack("C",0).pack("S",0).pack("L",$self->{sid}).pack("L",$blockNum).pack("S",0x0100).pack("S",IPcam::UPGRADE_DATA).pack("L",0);
			print "last packet                              \n";
		}elsif($len > 0){
			$pkt=pack("C",0xff).pack("C",0).pack("S",0).pack("L",$self->{sid}).pack("L",$blockNum).pack("S",0).pack("S",IPcam::UPGRADE_DATA).pack("L",$len).$udata;
			print "packet".$blockNum." sz=".length($pkt)."\r";
		}else{
			print "File read error\n";
	    	exit(1);
		}
	    $self->{socket}->send($pkt);
	    $reply_head = $self->GetReplyHead();
	    $out = $self->GetReplyData($reply_head);
		$blockNum++;
		eval {
     		# code that might throw exception
			$repl = $json->decode($out);
		};
		if ($@) {
    		# report the exception and do something about it
			print $@."decode_json exception. data:" . $out ."\n";
			print "Upgrade failed\n";
	    	exit(1);
		}
		if($repl->{Ret} != 100)
		{
    			print $error_codes{$repl->{Ret}}."\n";
			exit(1);
		}
		if($len==0)
		{
			print "\nUpload successful.\nUpgrading...";
			last;
		}
	}
	close(IN);
	print("\n");
	while(1)
	{
	    $self->{socket}->send("");
		$reply_head = $self->GetReplyHead();
		$out = $self->GetReplyData($reply_head);
	
		eval {
			# code that might throw exception
			$repl = $json->decode($out);
		};
		if ($@) {
			# report the exception and do something about it
			print "decode_json exception. data:" . $out ."\n";
			print "Upgrade failed\n";
			exit(1);
		}
		if($repl->{Ret} == 513)
		{
		    $self->{socket}->send("");
    			print $error_codes{$repl->{Ret}}."\n";
			exit(1);
		}
		if($repl->{Ret} == 514)
		{
		    $self->{socket}->send("");
    			print $error_codes{$repl->{Ret}}."\n";
			exit(1);
		}
		if($repl->{Ret} == 515)
		{
		    $self->{socket}->send("");
    			print $error_codes{$repl->{Ret}}."\n";
			exit(1);
		}
		print "Progress:".$repl->{Ret}."%\r";
	}

}

package main;
use IO::Socket;
use IO::Socket::INET;
use Time::Local;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

my $cfgFile         = "";
my $cfgUser         = "";
my $cfgPass         = "";
my $cfgHost         = "";
my $cfgPort         = "";
my $cfgCmd          = undef;
my $cfgHashType     = "md5based";
my $cfgDebug        = 0;
my $cfgChannel      = 0;
my $cfgBeginTime    = '';
my $cfgEndTime      = '';
my $cfgDownload     = 0;
my $cfgQueryFile    = '';
my $cfgOption       = '';
my $cfgModUserName  = '';
my $cfgNewUserGroup = '';
my $cfgNewUserPass  = '';
my $cfgInputFile    = '';
my $cfgSetData      = '';
my $cfgJSONPretty   = 0;
my $cfgForceDisc    = 0;

my $help = 0;

my $result = GetOptions(
    "help|h"            => \$help,
    "outputfile|of|o=s" => \$cfgFile,
    "user|u=s"          => \$cfgUser,
    "pass|p=s"          => \$cfgPass,
    "host|hst=s"        => \$cfgHost,
    "port|prt=s"        => \$cfgPort,
    "command|cmd|c=s"   => \$cfgCmd,
    "hashtype|ht=s"     => \$cfgHashType,
    "channel|ch=s"      => \$cfgChannel,
    "begintime|bt=s"    => \$cfgBeginTime,
    "endtime|et=s"      => \$cfgEndTime,
    "download|dl"       => \$cfgDownload,
    "queryfile|qf=s"    => \$cfgQueryFile,
    "configoption|co=s" => \$cfgOption,
    "debug|d"           => \$cfgDebug,
    "username=s"        => \$cfgModUserName,
    "newusergroup=s"    => \$cfgNewUserGroup,
    "newuserpass=s"     => \$cfgNewUserPass,
    "inputfile|if=s"    => \$cfgInputFile,
    "setdata|sd=s"      => \$cfgSetData,
    "forcedisconn|fd"   => \$cfgForceDisc,
    "jsonpretty|jp"     => \$cfgJSONPretty,
);

pod2usage(1) if ($help);

if ( !( $cfgHost or $cfgPort or $cfgUser ) ) {
    print STDERR "You must set user, host and port!\n";
    pod2usage(1);
    exit(0);
}
my $socket = IO::Socket::INET->new(
    PeerAddr => $cfgHost,
    PeerPort => $cfgPort,
    Proto    => 'tcp',
    Timeout  => 10000,
    Type     => SOCK_STREAM,
    Blocking => 1
) or die "Error at line " . __LINE__ . ": $!\n";

print "Connecting to: host = $cfgHost port = $cfgPort\n"  if ($cfgDebug ne 0);

my $dvr = IPcam->new(
    host     => $cfgHost,
    port     => $cfgPort,
    user     => $cfgUser,
    password => $cfgPass,
    hashtype => $cfgHashType,
    debug    => $cfgDebug,
    channel  => $cfgChannel,
    socket   => $socket
);

my $savePath = '/tmp';

my $decoded = $dvr->CmdLogin();

$aliveInterval = $decoded->{'AliveInterval'};
$ret           = $decoded->{'Ret'};

print sprintf( "SessionID = 0x%08x\n", $dvr->{sid} )  if ($cfgDebug ne 0);
print sprintf( "AliveInterval = %d\n", $aliveInterval )  if ($cfgDebug ne 0);
print sprintf( "Ret = %d\n",           $ret )  if ($cfgDebug ne 0);
if ( $dvr->{sid} eq 0 ) {
    print "Cannot connect\n";
    exit(1);
}
elsif ( $ret >= 200 ) {
    print STDERR "Authentication failed\n";
    exit(1);
}

if ( $cfgCmd eq "OPTimeSetting" ) {

# we are running this twice since we currently don't know which packet variant applicable for the current equipment
    $decoded = $dvr->CmdOPTimeSetting(1);
    $decoded = $dvr->CmdOPTimeSetting();
}
elsif ( $cfgCmd eq "Users" ) {
    $decoded = $dvr->CmdUsers();
}
elsif ( $cfgCmd eq "Groups" ) {
    $decoded = $dvr->CmdGroups();
}
elsif ( $cfgCmd eq "SystemInfo" ) {
    my $decoded = $dvr->CmdSystemInfo();
    print Dumper $dvr->{GenericInfo} if ($cfgDebug ne 0);
    my $sysinfo=$dvr->getSystemInfo();
    print Dumper $sysinfo if ($cfgDebug ne 0);

    print "System running:" . $dvr->getDeviceRuntime() . "\n\n";
    
    foreach my $k (keys %{$sysinfo})
    {
        print "$k = " . $sysinfo->{$k} . "\n";
    }

    print "Build info:\n\n";

    my %versioninfo = $dvr->VersionInfo( $dvr->{SystemInfo}{SoftWareVersion} );

    foreach my $k ( keys %versioninfo ) {
        print "$k = " . $versioninfo{$k} . "\n";
    }

}
elsif ( $cfgCmd eq "StorageInfo" ) {
    $decoded = $dvr->CmdStorageInfo();
}
elsif ( $cfgCmd eq "WorkState" ) {
    $decoded = $dvr->CmdWorkState();
}
elsif ( $cfgCmd eq "LogExport" ) {
    my $filename = $cfgFile;

    if ( $filename eq "" ) {
        $filename = "logs.zip";
    }
    elsif ( $filename !~ /\.zip$/ ) {
        $filename .= ".zip";
    }

    $decoded = $dvr->LogExport($filename);

}
elsif ( $cfgCmd eq "ConfigExport" ) {
    my $filename = $cfgFile;

    if ( $filename eq "" ) {
        $filename = "configs.zip";
    }
    elsif ( $filename !~ /\.zip$/ ) {
        $filename .= ".zip";
    }

    $decoded = $dvr->ConfigExport($cfgFile);
}
elsif ( $cfgCmd eq "OEMInfo" ) {
    $decoded = $dvr->CmdOEMInfo();
}
elsif ( $cfgCmd eq "OPStorageManagerClear" ) {
    $decoded = $dvr->CmdOPStorageManager(
        {
            Action   => "Clear",
            PartNo   => 0,
            SerialNo => 0,
            Type     => "Data",
        }
    );
}
elsif ( $cfgCmd eq "OPStorageManagerPartition" ) {
    $decoded = $dvr->CmdOPStorageManager(
        {
            Action => "Partition",
            PartNo => 0,
            PartitionSize =>
              ( { "Record" => 853869 }, { "SnapShot" => 100000 } ),
            SerialNo => 0,
        }
    );
}
elsif ( $cfgCmd eq "OPStorageManagerRecover" ) {
    $decoded = $dvr->CmdOPStorageManager(
        {
            Action   => "Recover",
            PartNo   => 0,
            SerialNo => 0,
        }
    );
}
elsif ( $cfgCmd eq "OPStorageManagerRW" ) {
    $decoded = $dvr->CmdOPStorageManager(
        {
            Action   => "SetType",
            PartNo   => 0,
            SerialNo => 0,
            Type     => "ReadWrite",
        }
    );
}
elsif ( $cfgCmd eq "OPStorageManagerRO" ) {
    $decoded = $dvr->CmdOPStorageManager(
        {
            Action   => "SetType",
            PartNo   => 0,
            SerialNo => 0,
            Type     => "ReadOnly",
        }
    );
}
elsif ( $cfgCmd eq "OPFileQuery" ) {

    $cfgBeginTime = $dvr->ParseTimestamp($cfgBeginTime);
    $cfgEndTime   = $dvr->ParseTimestamp($cfgEndTime);

    if ( $dvr->{debug} ne 0 ) {
        print
"begin_time = '$cfgBeginTime' end_time = '$cfgEndTime' channel = '$cfgChannel'\n";
    }

    #my $decoded = $dvr->CmdSystemFunction();

    my $decoded = $dvr->CmdOPFileQuery(
        {
            BeginTime => $cfgBeginTime,
            EndTime   => $cfgEndTime,
            Channel   => int($cfgChannel),

            # search all channels instead of single
            #HighChannel => 0,
            #LowChannel => 255,
            DriverTypeMask => "0x0000FFFF",
            Event          => "*"
            ,  # * - All; A - Alarm; M - Motion Detect; R - General; H - Manual;
            Type => "h264"    #h264 or jpg
        }
    );

    if ( defined( $decoded->{'OPFileQuery'} ) ) {

        my $results_ref = $decoded->{'OPFileQuery'};

        if ( $dvr->{debug} ne 0 ) {
            print Dumper $results_ref;
        }

        foreach my $result (@$results_ref) {

            $result->{'FileLength'} = hex( $result->{'FileLength'} );

            print Dumper $result;
        }
    }

}
elsif ( $cfgCmd eq "OPLogQuery" ) {

    $cfgBeginTime = $dvr->ParseTimestamp($cfgBeginTime);
    $cfgEndTime   = $dvr->ParseTimestamp($cfgEndTime);

    if ( $dvr->{debug} ne 0 ) {
        print "begin_time = '$cfgBeginTime' end_time = '$cfgEndTime'\n";
    }

    $decoded = $dvr->CmdOPLogQuery(
        {
            BeginTime   => $cfgBeginTime,
            EndTime     => $cfgEndTime,
            LogPosition => 0,
            Type        => "LogAll",
        }
    );

    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{OPLogQuery} );

}
elsif ( $cfgCmd eq "Download" ) {

    $cfgBeginTime = $dvr->ParseTimestamp($cfgBeginTime);
    $cfgEndTime   = $dvr->ParseTimestamp($cfgEndTime);

    if ( $dvr->{debug} ne 0 ) {
        print "begin_time = '$cfgBeginTime' end_time = '$cfgEndTime' channel = '$cfgChannel'\n";
    }

    #my $decoded = $dvr->CmdSystemFunction();

    my $decoded = $dvr->CmdOPFileQuery(
        {
            BeginTime => $cfgBeginTime,
            EndTime   => $cfgEndTime,
            Channel   => int($cfgChannel),

            # search all channels instead of single
            #HighChannel => 0,
            #LowChannel => 255,
            DriverTypeMask => "0x0000FFFF",
            Event          => "*"
            ,  # * - All; A - Alarm; M - Motion Detect; R - General; H - Manual;
            Type => "h264"    #h264 or jpg
        }
    );

    if ( defined( $decoded->{'OPFileQuery'} ) ) {

        my $results_ref = $decoded->{'OPFileQuery'};

        if ( $dvr->{debug} ne 0 ) {
            print Dumper $results_ref;
        }

        foreach my $result (@$results_ref) {
            print "result\n";

            my $flength = hex( $result->{'FileLength'} );

			$result->{'FileLength'} = $flength; #human readable

            print Dumper $result;

            $decoded = $dvr->CmdKeepAlive();

            if ( $decoded->{Ret} eq "100" ) {
                print "OPPlayBack: Claim\n";

                $decoded = $dvr->CmdOPPlayBack(
                    {
                        Action    => "Claim",
                        StartTime => $result->{'BeginTime'},
                        EndTime   => $result->{'EndTime'},
                        Parameter => {
                            FileName  => $result->{'FileName'},
                            PlayMode  => "ByName",
                            TransMode => "TCP",
                            Value     => 0
                        }
                    },
                    'test.h264'
                );

                if ( $decoded->{Ret} eq "100" ) {
                    print "OPPlayBack: DownloadStart\n";
                    my $data;

                    $dvr->CmdOPPlayBackDownloadStart(
                        {
                            Action    => "DownloadStart",
                            StartTime => $result->{'BeginTime'},
                            EndTime   => $result->{'EndTime'},
                            Parameter => {
                                FileName  => $result->{'FileName'},
                                PlayMode  => "ByName",
                                TransMode => "TCP",
                                Value     => 0
                            }
                        },
                        $flength
                    );

                }
                else {
                    print "Ret 2 NOT 100: " . $decoded->{Ret} . "\n";
                }

            }
            else {
                print "Ret 1 NOT 100\n";
            }
        }
    }

}
elsif ( $cfgCmd eq "ConfigGet" ) {

    my $json = JSON->new;
    $json->pretty($cfgJSONPretty);
    $decoded = $dvr->CmdConfigGet($cfgOption);
    my $param = {$decoded->{"Name"} => $decoded->{$decoded->{"Name"}}};
    $param = $json->encode($param);
    print $param."\n";
    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{$cfgOption} );

} elsif ($cfgCmd eq "Reboot") {

   $decoded = $dvr->PrepareGenericCommand(IPcam::SYSMANAGER_REQ, {Name => "OPMachine", OPMachine => { Action => "Reboot" }});

} elsif ($cfgCmd eq "Upgrade") {

	$dvr->CmdUpgrade($cfgInputFile);
  #$pkt=pack("CCSLLSSL",0xff,0x00,0,$self->{sid},$self->{sequence},0,$pktType,$size)

} elsif ( $cfgCmd eq "AuthorityList" ) {

    $decoded =
      $dvr->PrepareGenericCommand( IPcam::FULLAUTHORITYLIST_GET, undef );
    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{AuthorityList} );

}
elsif ( $cfgCmd eq "OPTimeQuery" ) {

    $decoded = $dvr->PrepareGenericCommand( IPcam::TIMEQUERY_REQ,
        { Name => 'OPTimeQuery' } );
    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{OPTimeQuery} );

}
elsif ( $cfgCmd eq "Ability" ) {

    $decoded = $dvr->PrepareGenericCommand( IPcam::ABILITY_GET,
        { Name => 'SystemFunction' } );
    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{SystemFunction} );

}
elsif ( $cfgCmd eq "User" ) {
    $decoded = $dvr->CmdGroups();

    my $groups = $decoded->{Groups};

    my $selected_group;

    foreach my $group (@$groups) {

        if ( $group->{Name} eq $cfgNewUserGroup ) {
            $selected_group = $group;
            break;
        }

    }

    #print Dumper $selected_group;

    if ( defined($selected_group) && defined($cfgModUserName) ) {
        my $pkt = {
            Name => 'User',
            User => {
                AuthorityList => $selected_group->{AuthorityList},
                Group         => $selected_group->{Name},
                Memo          => '',
                Name          => $cfgModUserName,
                Password      => $dvr->md5basedHash($cfgNewUserPass),
            }
        };

        my $json = JSON->new;

        $decoded = $dvr->PrepareGenericCommand( IPcam::ADDUSER_REQ, $pkt );
    }

}
elsif ( $cfgCmd eq "DeleteUser" ) {
    if (    defined($cfgModUserName)
        and $cfgModUserName ne 'admin'
        and $cfgModUserName ne 'user' )
    {
        $decoded = $dvr->PrepareGenericCommand( IPcam::DELETEUSER_REQ,
            { Name => $cfgModUserName } );
    }
}
elsif ( $cfgCmd eq "ChannelTitle" ) {
    $decoded = $dvr->PrepareGenericCommand( IPcam::CONFIG_CHANNELTILE_GET,
        { Name => "ChannelTitle" } );
    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded->{ChannelTitle} );
}
elsif ( $cfgCmd eq "ChannelTitleSet" ) {

    my @channeltitle = split( /,/, $cfgSetData );

    $decoded = $dvr->PrepareGenericCommand( IPcam::CONFIG_CHANNELTILE_SET,
        { Name => "ChannelTitle", ChannelTitle => \@channeltitle } );

}
elsif ( $cfgCmd eq "ConfigSet" ) {

    my $data = $cfgSetData;

    if($data eq "")
    {
        open( IN, "< $cfgInputFile" );

        while (<IN>) {
            $data .= $_;
        }
        close(IN);
    }
    my $json = JSON->new;
    $json->allow_nonref(1);
    my $jsondata = $json->decode($data);

    $decoded = $dvr->PrepareGenericCommand( IPcam::CONFIG_SET,
        { Name => $cfgOption, $cfgOption => $jsondata }, $cfgForceDisc );

    $dvr->WriteJSONDataToFile( $cfgFile, "json", $decoded );

}
elsif ( $cfgCmd eq "OPMonitor" ) {

    #  $decoded = $dvr->PrepareGenericCommand(IPcam::MONITOR_CLAIM, {
    #	    Name => "OPMonitor",
    #	    OPMonitor => {
    #      	  Action => "Claim",
    #      	  Parameter => {
    #	        Channel => $cfgChannel,
    #	        CombinMode => "NONE",
    #			StreamType => "Main",
    #	        TransMode => "TCP",
    #     	  }
    #		}
    #  });
    #$decoded = $dvr->CmdOPMonitorClaim();

    $decoded = $dvr->CmdSystemInfo();

    if ( $decoded->{'Ret'} eq "100" ) {
        print "SystemInfo ok\n";
    }

    $decoded = $dvr->CmdOPTimeSetting(1);

    $decoded = $dvr->PrepareGenericCommand( IPcam::GUARD_REQ, { Name => "" } );

    if ( $decoded->{'Ret'} eq "100" ) {
        print "Guard ok\n";
    }

    $decoded = $dvr->PrepareGenericCommand( IPcam::CONFIG_CHANNELTILE_GET,
        { Name => "ChannelTitle" } );

    if ( $decoded->{'Ret'} eq "100" ) {
        print "Channel title ok\n";
    }

    $decoded = $dvr->PrepareGenericCommand( IPcam::ABILITY_GET,
        { Name => "TalkAudioFormat" } );

    if ( $decoded->{'Ret'} eq "100" ) {
        print "TalkAudioFormat ok\n";
    }

    $decoded = $dvr->PrepareGenericCommand( IPcam::ABILITY_GET,
        { Name => "SystemFunction" } );

    if ( $decoded->{'Ret'} eq "100" ) {
        print "SystemFunction ok\n";

        #print Dumper $decoded;
    }

    $decoded = $dvr->CmdKeepAlive();

    print Dumper $decoded if ($cfgDebug ne 0);

    if ( $decoded->{'Ret'} eq "100" ) {
        print "KeepAlive ok\n";

        $decoded = $dvr->PrepareGenericCommand( IPcam::MONITOR_REQ,
            {
                Name      => "OPMonitor",
                OPMonitor => {
                    Action    => "Start",
                    Parameter => {
                        Channel    => int($cfgChannel),
                        StreamType => "Main",
                        TransMode  => "TCP"
                    }
                }
            }
        );

        if ( $decoded->{'Ret'} eq "100" ) {
            print "Monitor start confirm\n";

        }

    }

}elsif ($cfgCmd eq 'OPPTZControlContinue') { #update for continuose movement

    # DirectionRight, DirectionLeft, DirectionUp, DirectionDown, 
    # ZoomWide, ZoomTile, IrisLarge, IrisSmall, FocusNear, FocusFar
    my $ptzDirection = $cfgSetData; 

    foreach my $i (65535) {
        $decoded = $dvr->PrepareGenericCommand( IPcam::PTZ_REQ, {
            Name => "OPPTZControl",
            OPPTZControl =>  {
                Command => $ptzDirection,
                Parameter => {
                    AUX => {
                        Number => 0,
                        Status => "On"
                    },
                    Channel => int($cfgChannel),
                    MenuOpts => "Enter",
                    POINT => { "bottom" => 0, "left" => 0, "right" => 0, "top" => 0 },
                    Pattern => "SetBegin",
                    Preset => $i, # Preset: 65535 - start movement; -1 - stop movement
                    Step => 5,
                    Tour => 0
                }
            }
        });
    }

    if ( $decoded->{'Ret'} eq "100" ) {
        print "PTZ success\n";
    }

}elsif ($cfgCmd eq 'OPPTZControlStop') { #update for continuose movement

    # DirectionRight, DirectionLeft, DirectionUp, DirectionDown, 
    # ZoomWide, ZoomTile, IrisLarge, IrisSmall, FocusNear, FocusFar
    my $ptzDirection = $cfgSetData; 

    foreach my $i (-1) {
        $decoded = $dvr->PrepareGenericCommand( IPcam::PTZ_REQ, {
            Name => "OPPTZControl",
            OPPTZControl =>  {
                Command => $ptzDirection,
                Parameter => {
                    AUX => {
                        Number => 0,
                        Status => "On"
                    },
                    Channel => int($cfgChannel),
                    MenuOpts => "Enter",
                    POINT => { "bottom" => 0, "left" => 0, "right" => 0, "top" => 0 },
                    Pattern => "SetBegin",
                    Preset => $i, # Preset: 65535 - start movement; -1 - stop movement
                    Step => 5,
                    Tour => 0
                }
            }
        });
    }

    if ( $decoded->{'Ret'} eq "100" ) {
        print "PTZ success\n";
    }

} elsif ($cfgCmd eq 'OPPTZControl') {

    # DirectionRight, DirectionLeft, DirectionUp, DirectionDown, 
    # ZoomWide, ZoomTile, IrisLarge, IrisSmall, FocusNear, FocusFar
    my $ptzDirection = $cfgSetData; 

    foreach my $i (65535, -1) {
        $decoded = $dvr->PrepareGenericCommand( IPcam::PTZ_REQ, {
            Name => "OPPTZControl",
            OPPTZControl =>  {
                Command => $ptzDirection,
                Parameter => {
                    AUX => {
                        Number => 0,
                        Status => "On"
                    },
                    Channel => int($cfgChannel),
                    MenuOpts => "Enter",
                    POINT => { "bottom" => 0, "left" => 0, "right" => 0, "top" => 0 },
                    Pattern => "SetBegin",
                    Preset => $i, # Preset: 65535 - start movement; -1 - stop movement
                    Step => 5,
                    Tour => 0
                }
            }
        });
        sleep(0.5);
    }

    if ( $decoded->{'Ret'} eq "100" ) {
        print "PTZ success\n";
    }

}

print Dumper $decoded if ($cfgDebug ne 0);

#my $decoded = $dvr->CmdAlarmInfo({
#     Channel => 0,
#     Event => "VideoMotion",
#     StartTime => "2016-07-03 03:36:11",
#     Status => "Start"
#});

#my $decoded = $dvr->CmdOPNetAlarm(); #FIXME
#my $decoded = $dvr->CmdAlarmCenterMsg(); #FIXME

#my $decoded = $dvr->CmdOPNetKeyboard({
#     Status => "KeyUp",
#     Value => "0",
#});

#my $decoded = $dvr->CmdSnap(); #FIXME unsuppoted?

#my $decoded = $dvr->CmdOPLogQuery({
#        BeginTime => "2014-01-01 00:00:00",
#        EndTime => "2016-06-29 00:00:00",
#        LogPosition => 0,
#        Type => "LogAll",
#});

#my $pkt = {
#   Name => '',
#};

#my $decoded = $dvr->PrepareGenericDownloadCommand(IPcam::PHOTO_GET_REQ, $pkt, "out.dat");
#print Dumper $decoded;

$dvr->disconnect();

__END__

=head1 NAME

./sofiactl.pl - utility for working with Hi35xx Sofia powered DVR/NVR

=head1 SYNOPSIS

./sofiactl.pl [options]

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-of>

Path to output file filename.

=item B<-u>

Username

=item B<-p>

Password

=item N<-hashtype>

Hash type. "md5based" - md5 based hash calculation (modified md5, default), "plain" - use password hash as-is (plain text)

=item B<-host>

DVR/NVR hostname or ip address

=item B<-port>

DVR/NVR CMS port

=item B<-c>

DVR/NVR command: OPTimeSetting, Users, Groups, WorkState, StorageInfo, SystemInfo, OEMInfo, LogExport, ConfigExport, OPStorageManagerClear, OPFileQuery, OPLogQuery, ConfigGet, AuthorityList, OPTimeQuery, Ability, User, DeleteUser, ChannelTitle, ConfigSet, ChannelTitleSet, Reboot, Upgrade

=item B<-bt>

Search begin time

=item B<-et>

Search end time

=item B<-dl>

Download found files

=item B<-ch>

Channel number

=item N<-co>

Config option: Sections:  AVEnc, Ability, Alarm, BrowserLanguage, Detect, General, Guide, NetWork, Profuce, Record, Storage, System, fVideo, Uart, Simplify.Encode, Camera. Subsection could be requested in as object property, example: Uart.Comm

=item N<-username>

Name of adding/editing user

=item N<-newusergroup>

Group of new user. Must exists, permissions (authorities) will be copied from that group

=item M<-newuserpass>

Password for new user

=item N<-if>

Input file. Used for ConfigSet/Upgrade cmds

=item N<-sd>

Set data. Used in ChannelTitleSet, etc.

=item B<-d>

Debug output

=item B<-jp>

JSON pretty print

=item B<-fd>

force disconnect after parameter write (Useful when changing IP)

=back

=head1 DESCRIPTION

B<This program> can control the Hi35xx Sofia powered DVR/NVR.

=cut

