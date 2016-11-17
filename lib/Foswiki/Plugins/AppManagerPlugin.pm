# See bottom of file for default license and copyright information
package Foswiki::Plugins::AppManagerPlugin;

use strict;
use warnings;

# Foswiki modules
use Foswiki::Func    ();
use Foswiki::Meta    ();
use Foswiki::Plugins ();

# Core modules
use Carp;
use File::Find;
require File::Spec;
require File::Copy;
require File::Copy::Recursive;
require Digest::SHA;

# Extra modules
use JSON;

our $VERSION = '0.3';
our $RELEASE = '0.3';
our $SHORTDESCRIPTION  = 'Modell Aachen application installer';
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
    Foswiki::Func::registerRESTHandler('appuninstall', \&_RESTappuninstall, %restopts);
    Foswiki::Func::registerRESTHandler('installall', \&_RESTinstallall, %restopts);
    Foswiki::Func::registerRESTHandler('multisite', \&_RESTmultisite, %restopts);

    $restopts{http_allow} = 'GET';
    Foswiki::Func::registerRESTHandler('applist',   \&_RESTapplist,   %restopts);
    Foswiki::Func::registerRESTHandler('appdetail', \&_RESTappdetail, %restopts);
    return 1;
}

## Internal helpers

sub _getHistoryPath {
    my $app = shift;
    my $plugin = __PACKAGE__;
    $plugin =~ s/^Foswiki::Plugins:://;
    my $work = Foswiki::Func::getWorkArea($plugin);
    "$work/${app}_history.json";
}

sub _readHistory {
    my $app = shift;
    my $file = _getHistoryPath($app);
    my $history = Foswiki::Func::readFile($file, 1) || '{}';
    decode_json($history);
}

sub _writeHistory {
    my ($app, $history) = @_;
    my $file = _getHistoryPath($app);
    my $text = encode_json($history);
    Foswiki::Func::saveFile($file, $text, 1);
    1;
}

sub _appdetail  {
    my $id = shift;

    my $appConfig = _getJSONConfig($id);
    my $installed = [];
    if($appConfig){
        my $appHistory = _readHistory($appConfig->{appname});
        if($appHistory->{installed} && ref($appHistory->{installed}) eq "HASH"){
            my @webNames = keys(%{$appHistory->{installed}});
            while(@webNames){
                my $webName = pop(@webNames);
                push(@$installed, {
                    webName => $webName
                });
            }
        }
    }
    return {
        installed => $installed,
        appConfig => $appConfig
    };
}

sub _applist {
    my $searchString = ""._getRootDir()."/lib/Foswiki/";
    my @configs = ();
    find({
        wanted => sub {
            if($File::Find::name =~ /appconfig_new\.json$/){
                push(@configs, $File::Find::name);
            }
        },
        follow => 1,
        no_chdir => 1
        }, $searchString);
    my $appList = [];
    for my $appConfigPath (@configs) {
        my $appConfig = _getJSONConfig($appConfigPath);
        if ($appConfig) {
            push(@$appList, {
                id => $appConfigPath,
                name => $appConfig->{appname}
            });
        }
    }
    return $appList;
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfig {
    my $jsonPath = shift;

    my $res = undef;
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
                Foswiki::Func::writeWarning("Undefined json attributes for $jsonPath: " . join(', ', @missing));
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

sub _enableMultisite {
    if(_isMultisiteEnabled()){
        print STDERR "Multisite is already enabled.\n";
        return;
    }
    # Set SitePreferences
    my ($mainMeta, $mainText) = Foswiki::Func::readTopic("Main", "SitePreferences");
    $mainText =~ s/(\*\sSet\sMODAC_HIDEWEBS\s=\s.*)\n/$1|Settings|OUTemplate\n/;

    $mainText =~ s/(\*\sSet\sSKIN\s=\scustom,)(.*)\n/$1multisite,$2\n/;

    Foswiki::Func::saveTopic("Main","SitePreferences",$mainMeta,$mainText);

    # Copy MultisiteWebLeftBar
    my ($leftBarMeta,$leftBarText) = Foswiki::Func::readTopic("System","MultisiteWebLeftBarDefault");
    Foswiki::Func::saveTopic("Custom", "WebLeftBarDefault", $leftBarMeta, $leftBarText);
}

sub _disableMultisite {
    unless(_isMultisiteEnabled()){
        print STDERR "Multisite is already disabled\n";
        return;
    }
    # Remove SitePreferences
    my ($mainMeta, $mainText) = Foswiki::Func::readTopic("Main", "SitePreferences");
    $mainText =~ s/\|Settings\|OUTemplate//;

    $mainText =~ s/custom,multisite,/custom,/;

    Foswiki::Func::saveTopic("Main","SitePreferences",$mainMeta,$mainText);

    Foswiki::Func::moveTopic("Custom","WebLeftBarDefault",$Foswiki::cfg{TrashWebName}."/Custom","WebLeftBarDefault".time());
}

sub _isMultisiteAvailable {
    return Foswiki::Func::topicExists("System", "MultisiteWebLeftBarDefault");
}

sub _isMultisiteEnabled {
    my ($mainMeta, $mainText) = Foswiki::Func::readTopic("Main", "SitePreferences");
    return ($mainText =~ /\|Settings\|OUTemplate/);
}

sub _install {
    my ($appName, $installConfig) = @_;

    print STDERR "Starting installation for $appName...\n";

    my @configs;
    if ($installConfig->{subConfigs}) {
        @configs = @{$installConfig->{subConfigs}};
    }
    else {
        push (@configs, $installConfig);
    }

    foreach my $subConfig (@configs){
        print STDERR "Creating web(s)...\n";
        my $destinationWeb = $subConfig->{destinationWeb};
        if(Foswiki::Func::webExists($destinationWeb)){
            return {
                success => JSON::false,
                message => "The $destinationWeb web already exists."
            };
        }
        my $mergedSubwebs = "";
        foreach my $subweb (split(/\//, $destinationWeb)){
            $mergedSubwebs = $mergedSubwebs.$subweb;
            unless (Foswiki::Func::webExists($mergedSubwebs)) {
                eval {
                    Foswiki::Func::createWeb($mergedSubwebs);
                };
            }
            $mergedSubwebs = $mergedSubwebs."/";
        }

        print STDERR "Creating WebPreferences...\n";
        # Create WebPreferences
        my ($preferencesMeta, $defaultWebText) = Foswiki::Func::readTopic("System", "AppManagerDefaultWebPreferences");
        $defaultWebText =~ s/<DEFAULT_SOURCES_PREFERENCE>/$appName/;
        if($subConfig->{webPreferences}){
            # Add additional defined preferences
            foreach my $pref (@{$subConfig->{webPreferences}}){
                $preferencesMeta->putKeyed('PREFERENCE', {
                    name => $pref->{name},
                    title => $pref->{name},
                    value => $pref->{value}
                });
            }
        }
        Foswiki::Func::saveTopic($destinationWeb, "WebPreferences", $preferencesMeta, $defaultWebText);

        if($subConfig->{formConfigs}){
            print STDERR "Installing forms...\n";
            for my $formConfig (@{$subConfig->{formConfigs}}) {
                my $formName = $formConfig->{formName};
                my $formGroup = $formConfig->{formGroup};

                my $topic = "".$formName."Manager";

                my $meta = new Foswiki::Meta($Foswiki::Plugins::SESSION, $destinationWeb, $topic);
                $meta->putAll('PREFERENCE',
                    {
                        name => 'ALLOW_TOPICCHANGE',
                        title => 'ALLOW_TOPICCHANGE',
                        value => 'AdminGroup'
                    },
                    {
                        name => 'FormGenerator_AppControlled',
                        title => 'FormGenerator_AppControlled',
                        value => '1'
                    },
                    {
                        name => 'FormGenerator_Group',
                        title => 'FormGenerator_Group',
                        value => $formGroup
                    },
                    {
                        name => 'VIEW_TEMPLATE',
                        title => 'VIEW_TEMPLATE',
                        value => 'FormGeneratorManagerView'
                    },
                    {
                        name => 'WORKFLOW',
                        title => 'WORKFLOW',
                        value => ''
                    }
                );
                Foswiki::Func::saveTopic($destinationWeb, $topic, $meta, "");
                print STDERR "Created FormManager: $topic\n";
            }
        }

        # Create WebHome
        my $webHomeConfig = $subConfig->{webHomeConfig};
        my $webHomeMeta = undef;
        my $webHomeText = "";

        if ($webHomeConfig){
            print STDERR "Creating WebHome...\n";
            if (!$webHomeConfig->{copy} || $webHomeConfig->{copy} eq JSON::false){
                $webHomeMeta = new Foswiki::Meta($Foswiki::Plugins::SESSION, $destinationWeb, "WebHome");
                my $templateName = $webHomeConfig->{viewTemplate};
                if($templateName =~ /Template$/){
                    $templateName =~ s/Template$/''/;
                }
                $webHomeMeta->putAll('PREFERENCE',
                    {
                        name => 'ALLOW_TOPICCHANGE',
                        title => 'ALLOW_TOPICCHANGE',
                        value => 'AdminGroup'
                    },
                    {
                        name => 'VIEW_TEMPLATE',
                        title => 'VIEW_TEMPLATE',
                        value => 'System.'.$templateName
                    },
                    {
                        name => 'TOPICTITLE',
                        title => 'TOPICTITLE',
                        value => $webHomeConfig->{topicTitle}
                    }
                );

                if($webHomeConfig->{preferences}){
                    foreach my $pref (@{$webHomeConfig->{preferences}}){
                        $webHomeMeta->putKeyed('PREFERENCE', {
                            name => $pref->{name},
                            title => $pref->{name},
                            value => $pref->{value}
                        });
                    }
                }
            }
            else{
                my $templateName = $webHomeConfig->{viewTemplate};
                unless($templateName =~ /Template$/){
                    $templateName = $templateName."Template";
                }
                ($webHomeMeta,$webHomeText) = Foswiki::Func::readTopic("System",$templateName);
            }
            Foswiki::Func::saveTopic($destinationWeb, "WebHome", $webHomeMeta, $webHomeText);
        }
        else{
            print STDERR "No WebHome config provided. Skipping auto generation of WebHome!\n";
        }
        my $webActionsConfig = $subConfig->{webActionsConfig};
        if($webActionsConfig){
            print STDERR "Creating WebActions...\n";
            Foswiki::Func::saveTopic($destinationWeb, "WebActions", undef, '%INCLUDE{"%SYSTEMWEB%.'.$webActionsConfig->{sourceTopic}.'"}%');
        }
        else{
            print STDERR "No WebActions config provided. Skipping auto generation of WebActions!\n";
        }

        print STDERR "Creating WebTopicList...\n";
        Foswiki::Func::saveTopic($destinationWeb, "WebTopicList", undef, '%INCLUDE{"%SYSTEMWEB%.%TOPIC%"}%');

        print STDERR "Creating WebStatistics...\n";
        my ($webStatisticsMeta, $webStatisticsText) = Foswiki::Func::readTopic("System","AppManagerDefaultWebStatisticsTemplate");
        Foswiki::Func::saveTopic($destinationWeb, 'WebStatistics', $webStatisticsMeta, $webStatisticsText);

        print STDERR "Creating WebChanges...\n";
        Foswiki::Func::saveTopic($destinationWeb, "WebChanges", undef, '%INCLUDE{"%SYSTEMWEB%.%TOPIC%"}%');

        my $appContentConfig = $subConfig->{appContent};
        if($appContentConfig){
            print STDERR "Installing web content...\n";
            if(ref($appContentConfig) eq 'HASH'){
                my $contentConfig = $appContentConfig;
                $appContentConfig = [$contentConfig];

            }
            foreach my $appContent (@$appContentConfig){
                my $baseDir = $appContent->{baseDir};
                my $ignoredTopics = $appContent->{ignore} || [];
                my $linkedTopics = $appContent->{link} || [];
                my $targetDir;
                if($appContent->{targetDir}){
                    $targetDir = $appContent->{targetDir};
                    unless(Foswiki::Func::webExists($targetDir)){
                        Foswiki::Func::createWeb($targetDir);
                    }
                }
                else{
                    $targetDir = $destinationWeb;
                }
                if($linkedTopics){
                    push(@$ignoredTopics, @$linkedTopics);
                }
                print STDERR "Moving content from $baseDir to $targetDir...\n";
                if($appContent->{includeWebPreferences} && $appContent->{includeWebPreferences} eq JSON::true){
                    my ($webPrefMeta, $webPrefText) = Foswiki::Func::readTopic($baseDir, "WebPreferences");
                    Foswiki::Func::saveTopic($targetDir, "WebPreferences", $webPrefMeta, $webPrefText);
                }
                eval {
                    Foswiki::Plugins::FillWebsPlugin::_fill($baseDir, 0, $targetDir, 0, "", join("|", @$ignoredTopics), 1, 10);
                };
                if($@){
                    use Data::Dumper;
                    print STDERR Dumper($@);
                }

                # Create symlinks
                if($linkedTopics){
                    foreach my $topic (@$linkedTopics){
                        my $srcTopic = _getRootDir()."/data/".$baseDir."/".$topic.".txt";
                        my $destTopic = _getRootDir()."/data/".$targetDir."/".$topic.".txt";
                        symlink $srcTopic, $destTopic;
                    }
                }
            }
        }

        my $appHistory = _readHistory($appName);
        unless($appHistory->{installed} && ref($appHistory->{installed}) eq "HASH"){
            $appHistory->{installed} = {};
        }
        $appHistory->{installed}->{$destinationWeb} = {
            "installConfig" => $subConfig,
            "installDate" => time()
        };

        _writeHistory($appName, $appHistory);
    }

    return {
        success => JSON::true,
        message => "OK"
    };
}

sub _uninstall {
    my ($appName,$web) = @_;
    # Move web to trash
    # (with timestamp to avoid name clashes if webs with the same name are deleted multiple times)
    eval {
        Foswiki::Func::moveWeb($web, "Trash.$web".time());
    };

    if($@){
        #TODO: Check for valid errors.
    }

    # Remove from history
    my $history = _readHistory($appName);
    my %installed = %{$history->{installed}};
    delete $installed{$web};
    $history->{installed} = \%installed;
    _writeHistory($appName, $history);
}

sub _installAll {
    my $apps = _applist();
    foreach my $app (@$apps){
        my $appDetail = _appdetail($app->{id});
        my @installConfigs = @{$appDetail->{appConfig}->{installConfigs}};
        my $result = _install($appDetail->{appConfig}->{appname}, $installConfigs[0]);
        if($result->{success} eq JSON::true){
            print STDERR "Success!\n";
        }
        else{
            print STDERR "Installation failed: ".$result->{message}."\n";
        }
    }
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
    my $version = $q->param('version');

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

    my $q = $session->{request};
    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to list installed applications.'));
    }
    my $isMultisite = _isMultisiteEnabled();
    return encode_json({
        "apps" => _applist(),
        "multisite" => {
            "enabled" => _isMultisiteEnabled() ? JSON::true : JSON::false,
            "available" => _isMultisiteAvailable() ? JSON::true : JSON::false
        }
    });
}

# RestHandler to execute action for app
# installname: optional name to install
sub _RESTappaction {
    my ($session, $subject, $verb, $response) = @_;
    my $q = $session->{request};

    my $appId = $q->param('appId');
    my $installConfig = $q->param('installConfig');

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to execute actions.'));
    }
    unless ($appId)   {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'appId\' is mandatory'));
    }
    unless ($installConfig) {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'installConfig\' is mandatory'));
    }

    my $appConfig = _getJSONConfig($appId);
    my $appName = $appConfig->{appname};
    my $result = _install($appName, decode_json($installConfig));
    return encode_json($result);
}

sub _RESTappuninstall {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    my $appName = $q->param('appName');
    my $appWeb = $q->param('appWeb');

    _uninstall($appName, $appWeb);

    return encode_json({"status" => "ok"});
}

sub _RESTmultisite {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    my $enable = $q->param('enable');

    if($enable eq JSON::true){
        _enableMultisite();
    }
    elsif($enable eq JSON::false){
        _disableMultisite();
    }

    return encode_json({"success" => JSON::true});
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
