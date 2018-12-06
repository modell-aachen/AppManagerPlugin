package Foswiki::Plugins::AppManagerPlugin::AppConfigCreator;


use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(AppConfigCreator);

use JSON;
use Try::Tiny;
use Foswiki::Plugins::AppManagerPlugin;
use Foswiki::Plugins::AppManagerPlugin::AppManagerException qw( AppManagerException );

sub AppConfigCreator () { __PACKAGE__ };

sub new {
    my ( $class, $encodedConfig ) = @_;
    my $config = $class->_getJsonFrom($encodedConfig);
    $class->_checkSemanticOf($config);

    my $this = {
        config => $config,
        appname => $config->{appname},
    };
    bless $this, $class;

    return $this;
}

sub _getJsonFrom {
    my ( $class, $config ) = @_;

    try {
        return decode_json($config);
    } catch {
        die AppManagerException->new("json is not valid");
    };
}

sub _checkSemanticOf {
    my ( $this, $config ) = @_;
    for my $key ( qw( appname description) ) {
        if (not exists $config->{$key}) {
            die AppManagerException->new("${key} does not exist in appConfig");
        }
    }
}

sub run {
    my ( $this ) = @_;
    my $rootDir = Foswiki::Plugins::AppManagerPlugin::_getRootDir();
    my $appContribDir = "$rootDir/lib/Foswiki/Contrib/$this->{appname}";
    $this->_createDir($appContribDir);

    $this->_createAppConfigIn("$appContribDir/appconfig_new.json");
}

sub _createAppConfigIn {
    my ( $this, $file ) = @_;
    $this->_writeAppConfigTo($file);
}

sub _writeAppConfigTo {
    my ( $this, $file ) = @_;

    my $json = JSON->new;
    $json->pretty(1);
    $json->canonical(1);

    open(my $fh, '>', $file);
    print $fh $json->encode($this->{config});
    close $fh;
}

sub _createDir {
    my ( $this, $directory ) = @_;
    mkdir $directory;
}

1;
__END__
