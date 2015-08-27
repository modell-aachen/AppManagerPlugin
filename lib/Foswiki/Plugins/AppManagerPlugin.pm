# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;

# Foswiki modules
use Foswiki::Func    ();
use Foswiki::Plugins ();

# Core modules
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

    if (!Foswiki::Func::isAnAdmin()) {
        return 'Not allowed to list installed applications.';
    }

    my $template = &_buildTable('head');
    my @topicList = Foswiki::Func::getTopicList('System');
    my $contribspath = File::Spec->catdir($Foswiki::cfg{ScriptDir} . '/..', 'lib', 'Foswiki', 'Contrib');

    for my $contrib (@topicList) {
        if ($contrib =~ /AppContrib$/) {
            my $conf = _getJSONConfig($contrib);
            $template .= &_buildTable('content', $contrib, $conf);
        }
    }
    $template .= &_buildTable('foot');
    return $template;
}

# RestHandler to call _install routine for certain plugin
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
    return encode_json _install($conf, $args);
}

sub _buildTable {
    my ($format, $app, $conf) = @_;
    if ($format eq 'head') {
        #return '<table><thead><tr><td>Application</td><td>Description</td><td>Actions</td></tr></thead><tbody>';
        return "| Application | Description | Actions |\n";
    } elsif ($format eq 'foot') {
#        return '</tbody></table>';
        return '';
    } elsif ($format eq 'content') {
        my $statusref = _install($conf);
        my $status = join("%BR%", map((@$_)[0] . ': ' . (@$_)[1] ,@$statusref));
        # Check for non info notices
        my $button = '';
        my $check = {};
        map($check->{(@$_)[0]} = (@$_)[1],@$statusref);
        if (exists $check->{can_install} and $check->{can_install}) {
            $button = '%BR%%BUTTON{"Install" href="%SCRIPTURLPATH{"rest"}%/AppManagerPlugin/install?mode=install;app=' . $app . '"}%';
        }
        #return '<tr><td>' . $app . '</td><td>' . $conf->{description} . '</td><td>' . $status . '</td></tr>';
        return '| ' . $app . ' | ' . $conf->{description} . ' | ' . $status . $button . " |\n";
    }
}

# Check if "install" routine in conf are possible, and if mode eq 'install', install.
sub _install {
    my ($conf, $args) = @_;
    my $actions = $conf->{install};
    my $installname = '';
    if (exists $args->{installname} || exists $conf->{installname}) {
        $installname = $args->{installname} || $conf->{installname};
    }
    # Return notices
    my $res = [];
    # Iterate all install routines;
    for my $action (@$actions) {
        # We are only interested in the first object, the actual action.
        my $actA =  (keys $action)[0];
        if ($actA eq 'move') {
            # iterate all files to move
            my @toMove = @{$action->{'move'}};
            # take first key (should be only key from each object in move action
            my $note =  "Installation will move files as follows:%BR%";
            my @warnings = ();
            # Prepare subsitution strings
            # Iterate over move actions
            my @passes = ('check');
            if (($args->{mode} eq 'install') or ($args->{mode} eq 'forceinstall')) {
                push @passes, $args->{mode};
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
            } else {
                push @$res, ['can_install', '1'];
            }
        }
    }
    return $res;
}

# Return Foswiki root directory.
sub _getRootDir {
    # FIXME there has to be a better solution
    return $ENV{'DOCUMENT_ROOT'};
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfig {
    my $app = shift;
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
                    push @missing, $error;
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
