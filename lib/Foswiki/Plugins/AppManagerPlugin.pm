# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;

# Foswiki modules
use Foswiki::Func    ();
use Foswiki::Plugins ();

# Core modules
use Carp;
require File::Spec;
require File::Copy;
require File::Copy::Recursive;
require Digest::SHA;

# Extra modules
use JSON;

our $VERSION = '0.3';
our $RELEASE = '0.3';
our $SHORTDESCRIPTION  = 'AppManager';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ($topic, $web, $user, $installWeb) = @_;

    # check for Plugins.pm versions
    if ($Foswiki::Plugins::VERSION < 2.0) {
        Foswiki::Func::writeWarning('Version mismatch between ' . __PACKAGE__ . ' and Plugins.pm');
        return 0;
    }

    my %restopts = (authenticate => 1, validate => 0, http_allow => 'POST,GET');
    Foswiki::Func::registerRESTHandler('appaction', \&_RESTappaction, %restopts);
    Foswiki::Func::registerRESTHandler('installall', \&_RESTinstallall, %restopts);

    $restopts{http_allow} = 'GET';
    Foswiki::Func::registerRESTHandler('applist',   \&_RESTapplist,   %restopts);
    Foswiki::Func::registerRESTHandler('appdetail', \&_RESTappdetail, %restopts);
    return 1;
}

## Internal helpers
# Returns application details
sub _appdetail  {
    my ($app, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($app);

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
        if ($conf->{'install'}) {
            $actions->{install} = {
                "description" => "Install the application",
                "parameters" => {"appname" => { "type" => "text"}}
            };
            # "install" action implies "diff" action
            $actions->{diff} = $actions->{install};
        }
        $res->{actions} = $actions;
        return $res;
    } else {
        return _texterror('Not an application or application unmanaged');
    }
}

# Returns list of managed and unmanaged applications.
sub _applist {
    my $regex = $Foswiki::cfg{Plugins}{AppManagerPlugin}{AppRegExp} || '(App|Content)Contrib$';
    my @topicList = grep {/$regex/} Foswiki::Func::getTopicList('System');

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

# Returns formatted list of differences between installed and installable app.
sub _appdiff {
    my ($app, $appname, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($app);

    # Get operations
    my $result = '';
    my @operations = _installOperations($app, $appname);
    for (my $i = 0; $i < scalar @operations; $i += 3) {
        my ($op, $src, $tar) = ($operations[$i], $operations[$i+1], $operations[$i+2]);
        # Compare entries.
        my $msg = '';
        if (! -e $src) { $msg = "Source file or directory does not exist"; }
        elsif ( -d $src && -f $tar) { $msg =  "Source is a directory, but target is a file. This is most likely bad."; }
        elsif ( -f $src && -d $tar) { $msg =  "Source is a file, but target is a directory. This is most likely bad."; }
        elsif (( -f $src && -f $tar) && (_hashfile($src) ne _hashfile($tar))) { $msg = "Source file and target file have different content"; }
        elsif ( -d $src && -d $tar) { # Compare directories
            my ($srcdh, $tardh);
            unless (opendir($srcdh, $src)) { $msg = "Could not open source directory"; }
            unless (opendir($tardh, $tar)) { $msg = "Could not open target directory"; }
            unless ($msg) {
                # Compile unified list of readdir entries
                $msg .= "Both directories: $src, $tar. Differences:<ul>";
                my $list = {};
                map {$list->{$_} = 1;} grep {(!/^\./ && !/,pfv$/)} (readdir($srcdh), readdir($tardh));
                closedir($srcdh);
                closedir($tardh);
                for my $item (sort keys %$list) {
                    my ($srcitem, $taritem) = (File::Spec->catfile($src, $item), File::Spec->catfile($tar, $item));
                    if    (! -e $srcitem) { $msg .= "<li>$item only in target directory</li>"; }
                    elsif (! -e $taritem) { $msg .= "<li>$item only in source directory</li>"; }
                    # If both files/directories exists, compare
                    if ( -e $srcitem && -e $taritem) {
                        if ( -d $srcitem && -f $taritem) { $msg .=  "<li>$item is directory in source, but file in target directory. This is most likely bad.</li>"; }
                        elsif ( -f $srcitem && -d $taritem) { $msg .=  "<li>$item is file in source, but directory in target directory. This is most likely bad.</li>"; }
                        elsif ( -f $srcitem && -f $taritem && (_hashfile($srcitem) ne _hashfile($taritem))) { $msg .= "<li>$item: Source file and target file have different content</li>"; }
                        elsif ( -d $srcitem && -d $taritem) { $msg .= "<li>$item is a directory in both source and target. Comparison of subdirectories currently not implemented.</li>"; }
                    }
                }
                $msg .= '</ul>';
            }
        } elsif ( -d $src && (! -e $tar)) {
            $msg = "Target directory $tar does not exist. This ist not an error.";
        }
        # Compile result of operation, if messages found
        if ($msg) { $result .= sprintf("<p><strong>%s %s %s</strong></p>%s", $op, $src, $tar, $msg); }
    }
    return {
        "result" => "ok",
        "type" => "html",
        "data" => $result
    };
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfig {
    my ($app, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($app);

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
            for my $check (qw(description install installname appname)) {
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

#Return Foswiki root directory.
sub _getRootDir {
    # FIXME there has to be a better solution
    return $Foswiki::cfg{TemplateDir} . '/..';
}

# Check if "install" routine in conf are possible, and if mode eq 'install', install.
# $app is mandatory,
# $args is optional
sub _install {
    my ($app, $args, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($app);

    my $conf = _getJSONConfig($app);
    unless ($conf) {
        return _texterror("Application $app does not exist");
    }
    my $installname = '';
    my $mode = 'install';
    if (exists $args->{installname} || exists $conf->{installname}) {
        $installname = $args->{installname} || $conf->{installname};
    }
    if (exists $args->{mode}) {
        $mode = $args->{mode};
    }

    my @operations = _installOperations($app, $installname);
    # Return notices
    my @log = ();
    my $error = 0;
    my @passes = ('check');
    if (($mode eq 'install') or ($mode eq 'forceinstall')) { push @passes, $mode; }
    for my $pass (@passes) {
        # Skip installation pass if error and not forceinstall
        if (($pass eq 'install') and ($error)) {
            last;
        }
        push @log, "Run: $pass";
        # Iterate all install routines;
        foreach my $ops (@operations) {
            if ($ops->{action} eq 'move') {
                my $src = $ops->{from};
                my $tar = $ops->{to};

                unless ($src && $tar) {
                    $error = 1;
                    push @log, "Missing parameter 'from' and/or 'to'!";
                }

                push @log, "Move $src to $tar";
                if ($pass eq 'check') {
                    if (! -e $src) { $error = 1; push @log, "Source file or directory $src does not exist!"; }
                    if ( -e $tar)  { $error = 1; push @log, "Target file or directory $tar does already exist!"; }
                } elsif ((($pass eq 'install') and (! $error)) or ($pass eq 'forceinstall')) {
                    if ($args->{copy}) {
                        no warnings 'once';
                        local $File::Copy::Recursive::CopyLink = 0;
                        File::Copy::Recursive::rcopy($src, $tar);
                    } else {
                        File::Copy::move($src, $tar);
                    }
                }
            }

            if ($ops->{action} eq 'replace_text') {
                my $regexp = $ops->{pattern};
                my $text = $ops->{text};
                my $topics = $ops->{topics};
                unless ($regexp && $text) {
                    $error = 1;
                    push @log, "Missing parameter 'pattern' and/or 'text'!";
                }

                # We're unable to to replace anything during action 'check'.
                # The destination might not exist yet.
                next if $pass eq 'check';

                foreach my $t (@$topics) {
                    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $t);
                    unless (Foswiki::Func::topicExists($web, $topic)) {
                        $error = 1;
                        push @log, "$web.$topic doesn't exist!";
                        next;
                    }

                    my ($meta) = Foswiki::Func::readTopic($web, $topic);
                    my $contents = Foswiki::Serialise::serialise($meta, 'Embedded');
                    $contents =~ s/$regexp/$text/gm;

                    if (($pass eq 'install' && !$error) || $pass eq 'forceinstall') {
                        $meta = Foswiki::Meta->new($meta->session, $web, $topic);
                        Foswiki::Serialise::deserialise($contents, 'Embedded', $meta);
                        $meta->save({dontlog => 1, minor => 1, nohandlers => 1});
                    }

                    $meta->finish();
                }
            }
        }
    }
    my $result;
    my $log = join('', map {sprintf('<li>%s</li>', $_)} @log);
    if ($error) {
        $result = {
            "result" => "error",
            "type"   => "html",
            "data"   => (sprintf("<p><strong>Error during checks</strong></p><ul>%s</ul>", $log))
        };
    } else {
        $result = {
            "result" => "ok",
            "type"   => "html",
            "data"   => (sprintf("<p><strong>Appaction successful</strong></p><ul>%s</ul>", $log))
        };
    }
    return $result;
}

# Return sha256 checksum of content of file.
sub _hashfile {
    my $file = shift;
    open(my $fh, '<', $file);
    local $/;
    return Digest::SHA::sha256_hex(<$fh>);
};

sub _replacePlaceholder {
    my $installname = shift;
    my $data = $Foswiki::cfg{DataDir};
    my $pub = $Foswiki::cfg{PubDir};

    map {
        $_ =~ s/%INSTALLNAME%/$installname/g;
        $_ =~ s/%DATADIR%/$data/g;
        $_ =~ s/%PUBDIR%/$pub/g;
    } @_;
}

# Install operations
sub _installOperations {
    my ($app, $appname, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($app);

    my $conf = _getJSONConfig($app);
    my $installname = $appname || $conf->{installname};
    my @operations = @{$conf->{install}};

    foreach my $ops (@operations) {
        if ($ops->{action} eq 'move') {
            _replacePlaceholder($installname, $ops->{from}, $ops->{to});
        } elsif ($ops->{action} eq 'replace_text') {
            _replacePlaceholder($installname, $ops->{pattern}, $ops->{text}, @{$ops->{topics}});
        }
    };

    return @operations;
}

# Return text error.
sub _texterror {
    my ($msg, @bad) = @_;
    die "Extra parameters in " . (caller(0))[3] if @bad;
    map { confess "Mandatory parameter not defined in ".(caller(0))[3] unless defined $_} ($msg);

    return {
        "result" => "error",
        "type" => "text",
        "data" => $msg
    };
}

## Registered handlers
# Returns application details
sub _RESTappdetail {
    my ($session, $subject, $verb, $response) = @_;
    my $q = $session->{request};
    my $app = $q->param('name');

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to use this.'));
    }

    $response->header(-status => !$app ? 400 : 200);
    return encode_json(
        !$app
            ? _texterror('Parameter \'name\' is mandatory')
            : _appdetail($app));
}

# Returns list of managed and unmanaged applications.
sub _RESTapplist {
    my ($session, $subject, $verb, $response) = @_;

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to list installed applications.'));
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
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to execute actions.'));
    }
    unless ($name)   {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'name\' is mandatory'));
    }
    unless ($action) {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'action\' is mandatory'));
    }

    # Check if action available
    if ((_appdetail($name)->{actions}->{$action}) || ($action eq 'install' && $name eq 'all')) {
        return encode_json(_install($name)) if $action eq 'install';
        return encode_json(_appdiff($name)) if $action eq 'diff';

        $response->header(-status => 400);
        return encode_json(_texterror('Action available, but no method defined.'));
    }

    $response->header(-status => 400);
    return encode_json(_texterror('Action not available for app.'));
}

# Returns list of managed and unmanaged applications.
sub _RESTinstallall {
    my ($session, $subject, $verb, $response) = @_;

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to install all applications.'));
    }
    # Try install routine for all managed apps
    my @log = ();
    my $error = 0;
    my $applist = _applist();
    while (my ($name, $status) = each %$applist) {
        if ($status eq 'managed') {
            my $detail = _appdetail($name);
            if ($detail->{actions}->{install}) {
                my $res = _install($name);
                if ($res->{result} ne 'ok') {
                    push @log, "Installation failed: $name";
                    $error = 1;
                } else {
                    push @log, "Installation succeeded: $name.";
                }
            }
        }
    }
    if ($error) {
        $response->header(-status => 500);
        return encode_json(_texterror(join(' ', ("Not all installations successful." ,@log))));
    }

    return encode_json({
        "result" => "ok",
        "type"   => "text",
        "data"   => (join(' ', ("All installations successful." ,@log)))
    });
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Andreas Hennes, Maik Glatki, Modell Aachen GmbH

Copyright (C) 2015-2016 Modell Aachen GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
