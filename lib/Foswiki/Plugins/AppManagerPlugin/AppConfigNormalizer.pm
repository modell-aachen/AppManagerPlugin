package Foswiki::Plugins::AppManagerPlugin::AppConfigNormalizer;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw( InstallConfig );


sub InstallConfig () { __PACKAGE__ };

sub normalize {
    my ( $class, $config ) = @_;

    my $normalizedConfig = $class->_normalizeSingleConfig($config);
    $normalizedConfig = $class->_normalizeSubConfigOf($normalizedConfig);


    return $normalizedConfig;
}

sub _normalizeSingleConfig {
    my ( $class, $config ) = @_;
    foreach my $preferences ( qw( webPreferences sitePreferences ) ) {
        if (_isObject($config->{$preferences})) {
            $config->{$preferences} = $class->_objectToArray( $config->{$preferences} );
        }
    }

    return $config;
}

sub _normalizeSubConfigOf {
    my ( $class, $config ) = @_;
    my $subConfigs = $config->{subConfigs};
    my @normalizedSubConfigs = ();
    if (defined $subConfigs) {
        foreach my $subConfig (@{$subConfigs}) {
            push @normalizedSubConfigs, InstallConfig->normalize($subConfig);
        }
        $config->{subConfigs} = \@normalizedSubConfigs;
    }

    return $config;
}

sub _objectToArray {
    my ( $class, $preferences ) = @_;
    my $array = [];
    foreach my $name (sort(keys %$preferences)) {
        my $preference = $preferences->{$name};
        if (_isObject($preference)) {
            $preference->{name} = $name;
        } else {
            $preference = { name => $name, value => $preference };
        }
        push @{$array}, $preference;
    };

    return $array;
}

sub _isObject {
    my ( $variable ) = @_;
    return (ref($variable) eq 'HASH');
}
