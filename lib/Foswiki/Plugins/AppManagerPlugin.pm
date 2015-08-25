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
    my $i = 0;
    my $appsFound = 0;
    my $contribspath = File::Spec->catdir($Foswiki::cfg{ScriptDir} . '/..', 'lib', 'Foswiki', 'Contrib');

    for ($i; $i < (scalar @topicList) ; $i++) {
        if ($topicList[$i] =~ /AppContrib$/) {
            $appsFound++;
            my $description = 'Could not find appconfig.json for AppContrib.';
            my $actions = '';
            my $jsonPath = File::Spec->catfile($contribspath, $topicList[$i], 'appconfig.json');
            my $jsonAppConfig = {};

            if (-e $jsonPath) {
                open( my $fh, '<', $jsonPath );
                local $/;
                my $json_text = <$fh>;
                Foswiki::Func::writeDebug("Appmanager:" . $json_text);
                close($fh);
                $jsonAppConfig = decode_json($json_text);

                if (exists $jsonAppConfig->{description}) {
                    $description = $jsonAppConfig->{description};
                } else {
                    $description = 'Description is not defined';
                }

                if (exists $jsonAppConfig->{install}) {
                    $actions = $jsonAppConfig->{install};
                }
            }
            $template .= &_buildTable('content', $topicList[$i], $description, $actions);
        }
    }
    $template .= &_buildTable('foot');

    if ($appsFound == 0) {
        return 0;
    }

    return $template;
}

sub _buildTable {
    if ($_[0] eq 'head') {
        return '<table><thead><tr><td>Application</td><td>Description</td><td>Actions</td></tr></thead><tbody>';
    } elsif($_[0] eq 'foot') {
        return '</tbody></table>';
    } else {
        my $state = &_checkInstall($_[3]);
        return '<tr><td>' . $_[1] . '</td><td>' . $_[2] . '</td><td>' . $state . '</td></tr>'
    }
}

sub _checkInstall {
    my @obj = $_[0];
    my $i = 0;
    my $result = '';

    for ($i ; $i < (scalar @obj) ; $i++) {
        $result .= ' . ';
    }

    return (scalar @obj);
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
