package Foswiki::Plugins::AppManagerPlugin::AppConfigNormalizer;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw( InstallConfig );


sub InstallConfig () { __PACKAGE__ };

sub normalize {
    my ( $class, $config ) = @_;

    $class->_normalizeSingleConfigIn($config);
    $class->_normalizeSubConfigIn($config);

    return $config;
}

sub _normalizeSingleConfigIn {
    my ( $class, $config ) = @_;
    foreach my $preferences ( qw( webPreferences sitePreferences ) ) {
        if (_isObject($config->{$preferences})) {
            $config->{$preferences} = $class->_objectToArray($config->{$preferences});
        }
        if (exists $config->{$preferences}) {
            $class->_normalizeValueInAll($config->{$preferences});
        }
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

sub _normalizeValueInAll {
    my ( $class, $preferences ) = @_;
    foreach my $preference (@{$preferences}) {
        $class->_normalizeValueInSingle($preference);
    }
}

sub _normalizeValueInSingle {
    my ( $class, $preference ) = @_;
    if (_isArray($preference->{value})) {
        $preference->{value} = join ',', @{$preference->{value}};
    }
}

sub _normalizeSubConfigIn {
    my ( $class, $config ) = @_;
    my $subConfigs = $config->{subConfigs};
    my @normalizedSubConfigs = ();
    if (defined $subConfigs) {
        foreach my $subConfig (@{$subConfigs}) {
            push @normalizedSubConfigs, InstallConfig->normalize($subConfig);
        }
        $config->{subConfigs} = \@normalizedSubConfigs;
    }
}

sub _isObject {
    my ( $variable ) = @_;
    return (ref($variable) eq 'HASH');
}

sub _isArray {
    my ( $variable ) = @_;
    return (ref($variable) eq 'ARRAY');
}
