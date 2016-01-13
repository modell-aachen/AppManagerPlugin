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

    # Workaround until a better interface comes around.
    Foswiki::Func::registerTagHandler('AMPUGLY', \&_uglytable);

    my %restopts = (authenticate => 1, validate => 0, http_allow => 'POST,GET');
    Foswiki::Func::registerRESTHandler('appaction', \&_RESTappaction, %restopts);

    $restopts{http_allow} = 'GET';
    Foswiki::Func::registerRESTHandler('applist',   \&_RESTapplist,   %restopts);
    Foswiki::Func::registerRESTHandler('appdetail', \&_RESTappdetail, %restopts);
    return 1;
}

## Internal helpers
# Returns application details
sub _appdetail  {
    my ( $app, @bad ) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ( $app );

    my $conf = _getJSONConfig($app);
    if ($conf) {
        my $res = {
            'description' => ($conf->{description}),
            'status' => 'Placeholder',
            'actions' => '',
        };
        # Autoreplace %SHORTDESCRIPTION%
        if ($res->{description} eq '%SHORTDESCRIPTION%') {
            no strict 'refs';
            my $ref = sprintf('Foswiki::Contrib::%s::SHORTDESCRIPTION', $app);
            eval("require Foswiki::Contrib::$app;");
            $res->{description} = ${$ref};
        }

        # Collect actions
        my $actions = {};
        if ($conf->{'install'}) { $actions->{install} = {"description" => "Install the application", "parameters" => {"placeholder" => { "type" => "text"}}}; }
        $res->{actions} = $actions;
        return $res;
    } else {
        return {'error' => 'Not an application or application unmanaged'};
    }
}

# Returns list of managed and unmanaged applications.
sub _applist {
    my @topicList = grep {/AppContrib$/} Foswiki::Func::getTopicList('System');

    my $applist = {};
    for my $app (@topicList) {
        if (_getJSONConfig($app)) {
            $applist->{$app} = 'managed'; }
        else {
            $applist->{$app} = 'unmanaged';
        }
    }
    return $applist;
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

# Return Foswiki root directory.
sub _getRootDir {
    # FIXME there has to be a better solution
    return $Foswiki::cfg{TemplateDir} . '/..';
}

# Check if "install" routine in conf are possible, and if mode eq 'install', install.
# $app is mandatory,
# $args is optional
sub _install {
    my ( $name, $args, @bad ) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ( $name);

    my @apps;
    if ($name eq 'all') {
        my $applist = _applist();
        while(my ($name, $status) = each %$applist) {
            if ($status eq 'managed') {
                my $detail = _appdetail($name);
                if ($detail->{actions}->{install}) {
                    push @apps, $name;
                }
            }
        }
    } else {
        @apps = ($name);
    }

    my $results = {};
    for my $app (@apps) {
        my $conf = _getJSONConfig($app);
        my $actions = $conf->{install};
        my $installname = '';
        my $mode = 'install';
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
            my $actA =  (keys %$action)[0];
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
                        my ($src, $tar) = ((keys %$move)[0], $move->{(keys %$move)[0]});
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
        $results->{$app} = $res;
    }
    return $results;
}

# Ugly workaround, FIXME remove soon
sub _uglytable {
    my $res = '<table class="Modac_Standard" style="width: 60%;"><thead><tr><th>App</th><th>Desc</th><th>Action</th></thead>';
    my $apps = _applist();
    while(my ($name, $status) = each %$apps) {
        if ($status eq 'managed') {
            my $detail = _appdetail($name);
            $res .= '<tr>';
            $res .= '<td>';
            $res .= $name;
            $res .= '</td>';
            $res .= '<td>';
            $res .= $detail->{description};
            $res .= '</td>';
            $res .= '<td>';
            for my $action (keys %{$detail->{actions}}) {
                $res .= '%BUTTON{"Action: ' . $action .'" href="%SCRIPTURLPATH{"rest"}%/AppManagerPlugin/appaction?name=' . $name . '&action=' . $action . '"}%';
            }
            $res .= '</td>';
            $res .= '</tr>';
        }
    }
    $res .= '<tr><td><b>Install all applications</b></td><td><b>Try to install all applications</b></td><td>%BUTTON{"Destroy Wiki" href="%SCRIPTURLPATH{"rest"}%/AppManagerPlugin/appaction?name=all&action=install"}%';
    $res .= '</table>';
    return $res;
}

## Registered handlers
# Returns application details
sub _RESTappdetail {
    my($session, $subject, $verb, $response) = @_;
    my $q = $session->{request};
    my $app = $q->param('name');

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        return encode_json({'error' => 'Only Admins are allowed to use this.'});
    }
    unless ($app) { return {'error' => 'Parameter \'name\' is mandatory'}; }
    return encode_json(_appdetail($app));
}

# Returns list of managed and unmanaged applications.
sub _RESTapplist {
    my ($session, $subject, $verb, $response) = @_;

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        return encode_json({'error' => 'Only Admins are allowed to list installed applications.'});
    }
    return encode_json(_applist());
}

# RestHandler to execute action for app
# installname: optional name to install
sub _RESTappaction {
    my ($session, $subject, $verb, $response) = @_;
    my $q = $session->{request};
    my $name = $q->param('name');
    my $action = $q->param('action');

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        return encode_json({'error' => 'Only Admins are allowed to execute actions.'});
    }
    unless ($name) { return encode_json({'error' => 'Parameter \'name\' is mandatory'}); }
    unless ($action) { return encode_json({'error' => 'Parameter \'action\' is mandatory'}); }

    # Check if action available
    if ((_appdetail($name)->{actions}->{$action}) || ($action eq 'install' && $name eq 'all')) {
        if ($action eq 'install') {
            return encode_json(_install($name));
        } else {
        return encode_json({'error' => 'Action available, but no method defined.'});
        }
    } else {
        return encode_json({'error' => 'Action not available for app.'});
    }
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
