# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;

# Foswiki modules
use Foswiki::Func    ();
use Foswiki::Plugins ();

# Core modules
use Carp;
use File::Spec;
use File::Copy;

# Extra modules
use JSON;

our $VERSION = '0.1';
our $RELEASE = '0.1';
our $SHORTDESCRIPTION  = 'AppManager';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning('Version mismatch between ' . __PACKAGE__ . ' and Plugins.pm');
        return 0;
    }

    Foswiki::Func::registerTagHandler('AMPAPPLIST', \&_AMPAPPLIST);
    Foswiki::Func::registerRESTHandler('install', \&_RESTinstall);
    return 1;
}

# List AppManager information for all AppContribs as a table.
sub _AMPAPPLIST {
    my($session, $params, $topic, $web, $topicObject) = @_;

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        return 'Not allowed to list installed applications.';
    }

    my @topicList = Foswiki::Func::getTopicList('System');

    #Foswiki::Func::writeWarning($contribspath);

    my $applist = {};
    for my $contrib (@topicList) {
        my $conf = _getJSONConfig($contrib);
        if (($contrib =~ /AppContrib$/) && ($conf))  {
            $applist->{$contrib} = $conf;
        }
    }
    return encode_json($applist);
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfig {
    my ( $app, @bad ) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ( $app );

    my $res = undef;
    my $jsonPath = File::Spec->catfile(_getRootDir(), 'lib', 'Foswiki', 'Contrib', $app, 'appconfig.json');
    if (-e $jsonPath) {
        my $fh;
        unless (open($fh, '<', $jsonPath)) {
            Foswiki::Func::writeWarning("Could not open file $jsonPath");
            return undef;
        } else {
            # Slurp file, read JSON
            local $/;
            my $json_text = <$fh>;
            close($fh);
            my $error = 0;
            my @missing = ();
            $json_text = Foswiki::Sandbox::untaintUnchecked($json_text);
            my $jsonAppConfig = decode_json($json_text);

            # Validate JSON structure
            for my $check (qw(description install appname)) {
                unless (exists $jsonAppConfig->{description}) {
                    push @missing, $check;
                    $error = 1;
                }
            }
            if ($error) {
                Foswiki::Func::writeWarning("Undefined json attributes for $app: " . join(', ', @missing));
            } else {
                $res = $jsonAppConfig;
            }
        }
    }
    return $res;
}

# RestHandler to call _install routine for certain plugin
# mode: check|install|forceinstall
# app: appname
# installname: optional name to install
sub _RESTinstall {
    my ($session, $subject, $verb, $response) = @_;
    my $params = $session->{request}->{param};
    my $args = {};
    my $app;

    if (exists $params->{mode}[0]) {
        $args->{mode} = $params->{mode}[0];
    } else {
        $args->{mode} = 'check';
    }
    if (exists $params->{installname}[0]) {
        $args->{installname} = $params->{installname}[0];
    }
    if (exists $params->{app}[0]) {
        $app = $params->{app}[0];
    } else {
        $response->status( 400 );
        return;
    }

    # Only Admins are allowed to install
    if ((($args->{mode} eq 'install') or ($args->{mode} eq 'forceinstall')) and (!Foswiki::Func::isAnAdmin())) {
        $response->status( 403 );
        return;
    }
    my $conf = _getJSONConfig($app);
    return encode_json(_install($conf, $args));
}

# Check if "install" routine in conf are possible, and if mode eq 'install', install.
# conf parameter is mandatory,
# args parameter is optional
sub _install {
    my ( $conf, $args, @bad ) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ( $conf);

    my $actions = $conf->{install};
    my $installname = '';
    my $mode = 'check';
    if (exists $args->{installname} || exists $conf->{installname}) {
        $installname = $args->{installname} || $conf->{installname};
    }
    if (exists $args->{mode}) {
        $mode = $args->{mode};
    }
    # Return notices
    my $res = [];
    # Iterate all install routines;
    for my $action (@$actions) {
        # We are only interested in the first object, the actual action.
        my $actA =  (keys $action)[0];
        if ($actA eq 'move') {
            # Iterate all files to move
            my @toMove = @{$action->{'move'}};
            # Take first key (should be only key from each object in move action
            my $note =  "Installation will move files as follows:%BR%";
            my @warnings = ();
            # Iterate over move actions
            my @passes = ('check');
            if (($mode eq 'install') or ($mode eq 'forceinstall')) {
                push @passes, $mode;
            }
            chdir _getRootDir();
            for my $pass (@passes) {
                # FIXME this duplication smells
                for my $move (@toMove) {
                    my ($src, $tar) = ((keys $move)[0], $move->{(keys $move)[0]});
                    # Substitute place holders in paths
                    if ($installname) {
                        $src =~ s/%INSTALLNAME%/$installname/g;
                        $tar =~ s/%INSTALLNAME%/$installname/g;
                    }
                    # Check existance of source and target files
                    if ($pass eq 'check') {
                        $note .= "$src to $tar%BR%";
                        unless ( -e $src) {
                            push @warnings, "Source file or directory $src does not exist!";
                        }
                        if ( -e $tar) {
                            push @warnings, "Target file or directory $tar does already exist!";
                        }
                    } elsif ((($pass eq 'install') and (! scalar @warnings)) or ($pass eq 'forceinstall')) {
                        Foswiki::Func::writeWarning("move $src to $tar.");
                        File::Copy::move($src, $tar);
                    }
                }
            }
            push @$res, ['info', $note];
            if (scalar @warnings) {
                push @$res, map(['warning', $_], @warnings);
            } elsif ($mode ne 'install') {
                push @$res, ['can_install', '1'];
            }
        }
    }
    return $res;
}

# Return Foswiki root directory.
sub _getRootDir {
    # FIXME there has to be a better solution
    return $Foswiki::cfg{TemplateDir} . '/..';
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Andreas Hennes, Maik Glatki, Modell Aachen GmbH

Copyright (C) 2015 Modell Aachen GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
