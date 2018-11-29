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

our %save_options;
if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
    %save_options = ( nohandlers => 1 );
} else {
    %save_options = ( nohandlers => 0 );
}
sub initPlugin {
    my ($topic, $web, $user, $installWeb) = @_;

    # check for Plugins.pm versions
    if ($Foswiki::Plugins::VERSION < 2.0) {
        Foswiki::Func::writeWarning('Version mismatch between ' . __PACKAGE__ . ' and Plugins.pm');
        return 0;
    }

    Foswiki::Func::registerTagHandler(
        'APPMANAGER', \&_APPMANAGER );

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

sub _printDebug {
    my $text = shift;
    if (Foswiki::Func::getContext()->{'command_line'}) {
        print STDERR $text;
    }
    else {
        Foswiki::Func::writeWarning($text);
    }
    return;
}

sub _getHistoryPath {
    my $app = shift;
    my $plugin = __PACKAGE__;
    $plugin =~ s/^Foswiki::Plugins:://;
    my $work = Foswiki::Func::getWorkArea($plugin);
    return "$work/${app}_history.json";
}

sub _readHistory {
    my $app = shift;
    my $file = _getHistoryPath($app);
    my $history = Foswiki::Func::readFile($file, 1) || '{}';
    return decode_json($history);
}

sub _writeHistory {
    my ($app, $history) = @_;
    my $file = _getHistoryPath($app);
    my $text = encode_json($history);
    Foswiki::Func::saveFile($file, $text, 1);
    return 1;
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
            # Do not list the multisite install as it is handled separately
            if($appConfig->{appname} eq 'MultisiteAppContrib'){
                next;
            }
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
            return;
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
        _printDebug("Multisite is already enabled.\n");
        return {
            success => JSON::false,
            message => "Multisite is already enabled."
        };
    }
    my $customWeb = Foswiki::Func::getPreferencesValue('CUSTOMIZINGWEB') || 'Custom';

    # Check if there already exists a custom WebLeftBar
    # If so, don't do anything
    if(Foswiki::Func::topicExists($customWeb, "WebLeftBarDefault")){
        return {
            success => JSON::false,
            message => "Enabling multisite creates a new WebLeftBarDefault in the custom web. Please first create a backup of the current custom WebLeftBarDefault and then delete it from the custom web in order to proceed."
        };
    }

    # Set SitePreferences
    _setOnPreferences({}, [
        {
            name => 'MODAC_HIDEWEBS',
            pattern => qr($),
            format => '|Settings|OUTemplate',
            skip => '\|Settings\|OUTemplate\b',
        },
        {
            name => 'SKIN',
            pattern => qr((\bcustom\s*,|^(?!\bcustom\s*,))), # matches 'custom,' if it exists, start anchor otherwise
            format => '$1multisite,',
            skip => '\bmultisite\b',
        }
    ]);

    # Copy MultisiteWebLeftBar
    my $systemWebName = $Foswiki::cfg{'SystemWebName'} || 'System';
    my ($leftBarMeta,$leftBarText) = Foswiki::Func::readTopic($systemWebName,"MultisiteWebLeftBarDefault");
    Foswiki::Func::saveTopic($customWeb, "WebLeftBarDefault", $leftBarMeta, $leftBarText, \%save_options);


    # Install the MultisiteAppContrib
    my $appConfig = _getJSONConfig(_getRootDir().'/lib/Foswiki/Contrib/MultisiteAppContrib/appconfig_new.json');
    my $appName = $appConfig->{appname};
    _install($appName, $appConfig->{installConfigs}[0]);

    return {
        success => JSON::true,
        message => "Multisite enabled."
    };
}

# Parameters:
#    * settings: See SetOnPreferencesText
sub _setOnPreferences {
    my ($config, $settings, $altSection, $webtopic) = @_;

    my ($web, $topic, $meta, $text);
    unless (ref $webtopic) {
        $webtopic ||= $Foswiki::cfg{'LocalSitePreferences'};
        ($web, $topic) = Foswiki::Func::normalizeWebTopicName('', $webtopic);
        ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
    } else {
        $meta = $webtopic;
        $web = $meta->web();
        $topic = $meta->topic();
        $text = $meta->text();
    }

    $text = _setOnPreferencesText($config, $settings, $text, $altSection);

    Foswiki::Func::saveTopic($web, $topic, $meta, $text, \%save_options);
}

# Parameters:
#    * settings: array of settings to set, each item being a hash with options
#      as described in the plugin doku
#       * skip: when old value matches this regex, keep old value
#    * text: the text of a preferences topic
#    * altHeadnings: default for settings.altHeadings; defaults itself to
#      ['Modell Aachen Settings', 'Project Settings']
#
# Returns:
#    * modified text
sub _setOnPreferencesText {
    my ($config, $settings, $text, $altHeadings) = @_;

    $altHeadings = ['Modell Aachen Settings', 'Project Settings'] unless $altHeadings && (not ref $altHeadings || scalar @$altHeadings);

    # will replace &{settingname} with the actual config->{settingname} value
    # will not replace \${...}
    my $_settify = sub {
        my ($text) = @_;
        $text =~ s#(?<!\\)\&\{([^}]*)\}#defined $config->{$1} ? $config->{$1} : ''#ge;

        return $text;
    };

    # returns a "   * Set NAME = Value" string
    # Parameters:
    #    * setString: first part of the setting "   * Set NAME = "
    #    * oldValue: the current value; used as fallback
    #    * vSettings: settings for the value
    my $_getSetString = sub {
        my ($setString, $oldValue, $vSettings) = @_;

        return '' if $vSettings->{remove};

        my $value = $oldValue;

        my $doSkip;
        if(defined $vSettings->{skip}) {
            my $skip = $vSettings->{skip};
            $skip = &$_settify($skip);

            $doSkip = 1 if $value =~ m#$skip#;
        }

        unless ($doSkip) {
            if(defined $vSettings->{pattern}) {
                my $format = $vSettings->{format};
                $format = '' unless defined $format;
                $format = '"'.$format.'"'; # prepare for the ee flag

                my $pattern = $vSettings->{pattern};
                $pattern = &$_settify($pattern);

                unless ($value =~ s/$pattern/$format/ee) {
                    $value = $vSettings->{value} if defined $vSettings->{value};
                }
            } elsif(defined $vSettings->{value}) {
                $value = $vSettings->{value};
            }

            $value = &$_settify($value);
        }

        return "$setString$value";
    };

    foreach my $setting (@$settings) {
        my $name = $setting->{name};
        unless ($name) {
            # XXX this warning is not ideal, since it does not tell which app
            # or configuration is faulty
            Foswiki::Func::writeWarning("Invalid setting had no name");
            next;
        }

        # try find/replace an old value first
        # note: not using $Foswiki::regex{setRegex}, because it also matches
        # 'Local'
        unless($text =~ s/($Foswiki::regex{bulletRegex}\h+Set\h+\Q$name\E\h*=\h*)(.*)/&$_getSetString($1, $2, $setting)/me) {
            # Ok, we did not find an old value

            # Do we want a value?
            next if $setting->{remove};

            # Do nothing if we have no fallback
            unless (defined $setting->{value}) {
                Foswiki::Func::writeWarning("Invalid setting had no value or pattern") unless defined $setting->{pattern};
                next;
            }

            # let's insert after the marker
            my $heading;
            my $headings = $setting->{altHeadings};
            $headings = $altHeadings unless defined $headings && ((not ref $headings) || scalar @$headings);
            $headings = [$headings] unless ref $headings;
            foreach my $h (@$headings) {
                next unless ($text =~ m/^---\++\h*\Q$h\E\s*$/m);
                $heading = $h;
                last;
            }
            unless ($heading) {
                # this should normally not happen, thus an ugly fallback should be
                # sufficient
                $heading = $headings->[0];
                $text = "---++ $heading\n\n$text";
            }
            my $value = &$_settify($setting->{value});
            $text =~ s/(^---\++\h*\Q$heading\E\s*\n)/$1   * Set $setting->{name} = $value\n/m;
        }
    }

    return $text;
}

sub _disableMultisite {
    unless(_isMultisiteEnabled()){
        _printDebug("Multisite is already disabled\n");
        return {
            success => JSON::false,
            message => "Multisite is already disabled."
        };
    }

    #Uninstall the Settings and OUTemplate webs
    _uninstall('MultisiteAppContrib', 'Settings');
    _uninstall('MultisiteAppContrib', 'OUTemplate');

    # Remove SitePreferences
    _setOnPreferences({}, [
        {
            name => 'MODAC_HIDEWEBS',
            format => '',
            pattern => qr(\|Settings\|OUTemplate),
        },
        {
            name => 'SKIN',
            format => '',
            pattern => qr(multisite,),
        },
    ]);

    my $customWeb = Foswiki::Func::getPreferencesValue('CUSTOMIZINGWEB') || 'Custom';

    # Remove multisite WebLeftBarDefault
    Foswiki::Func::moveTopic($customWeb,"WebLeftBarDefault",$Foswiki::cfg{TrashWebName}."/$customWeb","WebLeftBarDefault".time());

    return {
        success => JSON::true,
        message => "Multisite disabled."
    };
}

sub _isMultisiteAvailable {
    my $systemWebName = $Foswiki::cfg{'SystemWebName'} || 'System';
    return Foswiki::Func::topicExists($systemWebName, "MultisiteWebLeftBarDefault");
}

sub _isMultisiteEnabled {
    my ($sitePrefWeb, $sitePrefTopic) = Foswiki::Func::normalizeWebTopicName('', $Foswiki::cfg{'LocalSitePreferences'});
    my ($mainMeta, $mainText) = Foswiki::Func::readTopic($sitePrefWeb, $sitePrefTopic);
    return ($mainText =~ /\|Settings\|OUTemplate/);
}

sub _install {
    my ($appName, $installConfig) = @_;
    my $failedToAddUser = 0;
    my $addUsersToProvider = $Foswiki::cfg{'UnifiedAuth'}{'AddUsersToProvider'};

    _printDebug("Starting installation for $appName...\n");

    my $systemWebName = $Foswiki::cfg{'SystemWebName'} || 'System';

    my @configs;
    if ($installConfig->{subConfigs}) {
        @configs = @{$installConfig->{subConfigs}};
    }
    else {
        push (@configs, $installConfig);
    }

    foreach my $subConfig (@configs){
        _printDebug("Creating web(s)...\n");
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

        _printDebug("Creating WebPreferences...\n");
        # Create WebPreferences
        my ($preferencesMeta, $defaultWebText) = Foswiki::Func::readTopic($systemWebName, "AppManagerDefaultWebPreferences");
        $defaultWebText =~ s/<DEFAULT_SOURCES_PREFERENCE>/$appName/;
        my $additionalWebPreferences = "";
        if($subConfig->{webPreferences}){
            $defaultWebText = _setOnPreferencesText($subConfig, $subConfig->{webPreferences}, $defaultWebText);
        }
        Foswiki::Func::saveTopic($destinationWeb, "WebPreferences", $preferencesMeta, $defaultWebText, \%save_options);

        # Modify SitePreferences
        if($subConfig->{sitePreferences} && $subConfig->{destinationWeb} !~ m/^_/) {
            _setOnPreferences($subConfig, $subConfig->{sitePreferences});
        }

        if($subConfig->{formConfigs}){
            _printDebug("Installing forms...\n");
            for my $formConfig (@{$subConfig->{formConfigs}}) {
                my $formName = $formConfig->{formName};
                my $formGroup = $formConfig->{formGroup};

                my $topic = "".$formName."Manager";

                my $meta = Foswiki::Meta->new($Foswiki::Plugins::SESSION, $destinationWeb, $topic);
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
                _vAction(sub{
                    Foswiki::Func::saveTopic($destinationWeb, $topic, $meta, "", \%save_options);
                });
                _printDebug("Created FormManager: $topic\n");
            }
        }

        # Create WebHome
        my $webHomeConfig = $subConfig->{webHomeConfig};
        my $webHomeMeta = undef;
        my $webHomeText = "";

        if ($webHomeConfig){
            _printDebug("Creating WebHome...\n");
            if (!$webHomeConfig->{copy} || $webHomeConfig->{copy} eq JSON::false){
                $webHomeMeta = Foswiki::Meta->new($Foswiki::Plugins::SESSION, $destinationWeb, "WebHome");
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
                        value => "$systemWebName.".$templateName
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
                ($webHomeMeta,$webHomeText) = Foswiki::Func::readTopic($systemWebName,$templateName);
            }
            _vAction(sub{
                Foswiki::Func::saveTopic($destinationWeb, "WebHome", $webHomeMeta, $webHomeText, \%save_options);
            });
        }
        else{
            _printDebug("No WebHome config provided. Skipping auto generation of WebHome!\n");
        }
        my $webActionsConfig = $subConfig->{webActionsConfig};
        if($webActionsConfig){
            _printDebug("Creating WebActions...\n");
            _vAction(sub{
                Foswiki::Func::saveTopic($destinationWeb, "WebActions", undef, '%INCLUDE{"%SYSTEMWEB%.'.$webActionsConfig->{sourceTopic}.'"}%', \%save_options);
            });
        }
        else{
            _printDebug("No WebActions config provided. Skipping auto generation of WebActions!\n");
        }

        _printDebug("Creating WebStatistics...\n");
        my ($webStatisticsMeta, $webStatisticsText) = Foswiki::Func::readTopic($systemWebName,"AppManagerDefaultWebStatisticsTemplate");
        Foswiki::Func::saveTopic($destinationWeb, 'WebStatistics', $webStatisticsMeta, $webStatisticsText, \%save_options);

        # Note: All these could already be virtual topics
        foreach my $systemTopic ( qw(WebChanges WebSearch WebSearchAdvanced WebTopicList) ) {
            unless(Foswiki::Func::topicExists($destinationWeb, $systemTopic)) {
                _printDebug("Creating $systemTopic...\n");
                Foswiki::Func::saveTopic($destinationWeb, $systemTopic, undef, '%INCLUDE{"%SYSTEMWEB%.%TOPIC%"}%', \%save_options);
            }
        }

        if($subConfig->{groups}){
            _printDebug("Processing groups...\n");
            my @groupNames = keys(%{$subConfig->{groups}});
            foreach my $group (@groupNames){
                unless($group =~ /Group$/){
                    _printDebug("Invalid group name: $group. Skipping...\n");
                    next;
                }
                _printDebug("$group...\n");
                my @members = @{$subConfig->{groups}->{$group}};
                unless(@members){
                    # Unfortunately the Foswiki API does not seem to offer
                    # a more elegant way to create empty groups
                    Foswiki::Func::addUserToGroup("AdminUser", $group, 1);
                    Foswiki::Func::removeUserFromGroup("AdminUser", $group);
                    next;
                }

                foreach my $member (@members){
                    if(!_userExists($member)){
                        if($addUsersToProvider ne 'topic' ){
                            $failedToAddUser = 1;
                            Foswiki::Func::writeWarning('Failed to add user: adding users is not supported, please configure {UnifiedAuth}{AddUsersToProvider}.');
                            next;
                        }
                        _createUser($member);
                    }
                    if(!Foswiki::Func::isGroupMember($group, $member)){
                        _printDebug("Add User $member to $group\n");
                        Foswiki::Func::addUserToGroup($member, $group, 1);
                    }
                }
            }
        }

        my $appContentConfig = $subConfig->{appContent};
        if($appContentConfig){
            _printDebug("Installing web content...\n");
            if(ref($appContentConfig) eq 'HASH'){
                my $contentConfig = $appContentConfig;
                $appContentConfig = [$contentConfig];

            }
            foreach my $appContent (@$appContentConfig){
                my $baseDir = $appContent->{baseDir};
                my $ignoredTopics = $appContent->{ignore} || [];
                my $alwaysCopyTopics = $appContent->{alwaysCopy};
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
                my $alwaysCopyReg;
                if(defined $alwaysCopyTopics) {
                    $alwaysCopyReg = join("|", @$alwaysCopyTopics);
                }
                _printDebug("Moving content from $baseDir to $targetDir...\n");
                if($appContent->{includeWebPreferences} && $appContent->{includeWebPreferences} eq JSON::true){
                    my ($webPrefMeta, $webPrefText) = Foswiki::Func::readTopic($baseDir, "WebPreferences");
                    Foswiki::Func::saveTopic($targetDir, "WebPreferences", $webPrefMeta, $webPrefText, \%save_options);
                }
                eval {
                    Foswiki::Plugins::FillWebsPlugin::fill({
                        srcWeb => $baseDir,
                        recurseSrc => 1,
                        targetWeb => $targetDir,
                        recurseTarget => 0,
                        skipTopics => join("|", @$ignoredTopics),
                        unskipTopics => $alwaysCopyReg
                    });
                };
                if($@){
                    use Data::Dumper;
                    _printDebug(Dumper($@));
                    eval {
                        Foswiki::Func::moveWeb($destinationWeb, "Trash.$destinationWeb".time());
                    };
                    return {
                        success => JSON::false,
                        message => "Installation failed: Could not copy app content. Is the FillWebsPlugin installed?"
                    };
                }

                # Create symlinks
                if($linkedTopics){
                    foreach my $topic (@$linkedTopics){
                        next if $alwaysCopyReg && $topic =~ m#$alwaysCopyReg#;
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

    if($failedToAddUser){
        return {
            success => 'warning',
            message => 'Failed to add user: adding users is not supported, please configure {UnifiedAuth}{AddUsersToProvider}.'
        };
    }else{
        return {
            success => JSON::true,
            message => "OK"
        };
    }

}

sub _createUser {
    my($member) = @_;
    my $session = $Foswiki::Plugins::SESSION;
    my $users = $session->{users};
    _printDebug("Creating user with cUID=" . $users->addUser($member, $member, 'PW_'.$member, $member.'@qwiki.com') . "\n");
}

sub _userExists {
    my ($member) = @_;
    my $it = Foswiki::Func::eachUser();
    while($it->hasNext()){
        my $user = $it->next();
        if($user eq $member){
            return 1;
        }
    }
    return 0;
}

sub _vAction {
    if($Foswiki::Plugins::SESSION->{store}->can('doWithoutVirtualTopics')) {
        $Foswiki::Plugins::SESSION->{store}->doWithoutVirtualTopics(@_);
    } else {
        my $sub = shift;
        &$sub(@_);
    }
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
    my %installed = %{$history->{installed} || {}};
    delete $installed{$web};
    $history->{installed} = \%installed;
    _writeHistory($appName, $history);
    return;
}

sub _installAll {
    my $apps = _applist();
    foreach my $app (@$apps){
        my $appDetail = _appdetail($app->{id});
        my @installConfigs = @{$appDetail->{appConfig}->{installConfigs}};
        my $result = _install($appDetail->{appConfig}->{appname}, $installConfigs[0]);
        if($result->{success} eq JSON::true){
            _printDebug("Success!\n");
        }
        else{
            _printDebug("Installation failed: ".$result->{message}."\n");
        }
    }
    return;
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
    $response->body(encode_json(
        !$app
            ? _texterror('Parameter \'name\' is mandatory')
            : _appdetail($app)));
    return '';
}

# Returns list of managed and unmanaged applications.
sub _RESTapplist {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        $response->body(encode_json(_texterror('Only Admins are allowed to list installed applications.')));
        return '';
    }
    my $isMultisite = _isMultisiteEnabled();
    $response->body(encode_json({
        "apps" => _applist(),
        "multisite" => {
            "enabled" => _isMultisiteEnabled() ? JSON::true : JSON::false,
            "available" => _isMultisiteAvailable() ? JSON::true : JSON::false
        }
    }));
    return '';
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
        $response->body(encode_json(_texterror('Only Admins are allowed to execute actions.')));
        return '';
    }
    unless ($appId)   {
        $response->header(-status => 400);
        $response->body(encode_json(_texterror('Parameter \'appId\' is mandatory')));
        return '';
    }
    unless ($installConfig) {
        $response->header(-status => 400);
        $response->body(encode_json(_texterror('Parameter \'installConfig\' is mandatory')));
        return '';
    }

    my $appConfig = _getJSONConfig($appId);
    my $appName = $appConfig->{appname};
    my $result = _install($appName, decode_json($installConfig));
    $response->body(encode_json($result));
    return '';
}

sub _RESTappuninstall {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    my $appName = $q->param('appName');
    my $appWeb = $q->param('appWeb');

    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        $response->body(encode_json(_texterror('Only Admins are allowed to use this.')));
        return '';
    }

    _uninstall($appName, $appWeb);

    $response->body(encode_json({"status" => "ok"}));
    return '';
}

sub _RESTmultisite {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    my $enable = $q->param('enable');

    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        $response->body(encode_json(_texterror('Only Admins are allowed to use this.')));
        return '';
    }

    my $result;

    if($enable eq JSON::true){
        $result = _enableMultisite();
    }
    elsif($enable eq JSON::false){
        $result = _disableMultisite();
    }

    $response->body(encode_json($result));
    return '';
}

sub _APPMANAGER {
    my ( $session, $attributes, $topic, $web, $meta ) = @_;

    Foswiki::Func::addToZone( 'script', 'APPMANAGERCONTRIB::SCRIPTS',
        "<script type='text/javascript' src='%PUBURLPATH%/System/AppManagerPlugin/appmanager.js?v=$RELEASE'></script>","VUEJSPLUGIN,JQUERYPLUGIN"
    );

    my $clientToken = Foswiki::Plugins::VueJSPlugin::getClientToken();
    return <<HTML;
        <div class="AppManagerContainer" data-vue-client-token="$clientToken"><app-list></app-list></div>
HTML
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
