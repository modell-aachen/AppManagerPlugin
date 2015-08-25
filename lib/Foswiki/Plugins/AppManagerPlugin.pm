# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;
use Foswiki::Func    ();
use Foswiki::Plugins ();
use File::Spec;
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
    return 1;
}

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

sub _buildTable {
    my ($format, $app, $conf) = @_;
    if ($format eq 'head') {
        #return '<table><thead><tr><td>Application</td><td>Description</td><td>Actions</td></tr></thead><tbody>';
        return "| Application | Description | Actions |\n";
    } elsif ($format eq 'foot') {
#        return '</tbody></table>';
        return '';
    } elsif ($format eq 'content') {
        my $statusref = _checkInstall($conf);
        my $status = join(" ", @$statusref);
        #return '<tr><td>' . $app . '</td><td>' . $conf->{description} . '</td><td>' . $status . '</td></tr>';
        return '| ' . $app . ' | ' . $conf->{description} . ' | ' . $status . " |\n";
    }
}

# Check if "install" routines in conf are possible
sub _checkInstall {
    my $conf = shift;
    my $actions = $conf->{install};
    # Return notices
    my $res = [];
    # Check install actions;
    for my $action (@$actions) {
        push @$res, join(", ", keys($action));
        # push @$res, $action;
    }
    return $res;
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfig {
    my $app = shift;
    my $res = undef;
    my $jsonPath = File::Spec->catfile($Foswiki::cfg{ScriptDir} . '/..', 'lib', 'Foswiki', 'Contrib', $app, 'appconfig.json');
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
