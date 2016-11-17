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
    Foswiki::Func::registerRESTHandler('topiclist', \&_RESTtopiclist, %restopts);
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

sub _appdetailnew  {
    my $id = shift;

    my $appConfig = _getJSONConfigNew($id);
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

# This action is responsible for generating FormManagers
# for a given web. It is based on the desired form name and
# form group. FormGenerators need to be installed by the Plugin/Contrib.
sub _actionCreateForm {
    my ($web, $formName, $formGroup) = @_;
    my $topic = "".$formName."Manager";

    my $meta = new Foswiki::Meta($Foswiki::Plugins::SESSION, $web, $topic);
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
    Foswiki::Func::saveTopic($web, $topic, $meta, "");
    print STDERR "Created FormManager: $topic\n";
}

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

        my $installed = Foswiki::Func::webExists($conf->{installname} || '') ? JSON::true : JSON::false;
        my $extras = '';
        my $history = _readHistory($app);
        if ($history->{installed} && scalar(@{$history->{installed}})) {
            $extras .= "*Installed as*:\n";
            foreach my $w (@{$history->{installed}}) {
                $extras .= "   * [[$w.WebHome][$w]]\n";
            }
        } elsif ($installed) {
            # assume app is installed to its default location as specified in
            # its appconfig.json
            $extras .= "*Installed as*:\n   * [[$conf->{installname}.WebHome][$conf->{installname}]]\n";
        }

        if ($history->{linked} && scalar(@{$history->{linked}})) {
            $extras .= "*Linked to*:\n";
            foreach my $w (@{$history->{linked}}) {
                $extras .= "   * [[$w.WebHome][$w]]\n";
            }
        }

        if ($history->{partials}) {
            $extras .= "*Partially linked to* (click for further details):\n";
            foreach my $partial (keys %{$history->{partials}}) {
                my $topics = join("\n", map {"      * [[$partial.$_][$_]]"} @{$history->{partials}->{$partial}});
                $extras .= "   * %TWISTY{link=\"$partial\" mode=\"span\"}%\n$topics%ENDTWISTY%\n";
            }
        }

        $installed = JSON::true if $extras;
        my $labelClass = ($installed == JSON::true) ? 'installed' : 'uninstalled';
        my $text = <<DESC;
   * *Description*: $res->{description} <a href="%SCRIPTURLPATH{view}%/System/$app" target="_blank">(more)</a>
   * *Installed*: <span class="label $labelClass">$installed</span>
   * *Version*: %QUERYVERSION{"$app"}%
DESC

        $text .= <<EXTRAS if $extras;
---
$extras
EXTRAS

        my $meta = Foswiki::Meta->new($Foswiki::Plugins::SESSION);
        $res->{description} = $meta->expandMacros(Foswiki::Func::renderText($text));

        # Collect actions
        my $actions = {};
        if ($conf->{'install'}) {
            $actions->{install} = {
                "description" => "Install the application",
                "parameters" => {"appname" => { "type" => "text"}},
                "installed" => $installed,
                "allowsCopy" => $conf->{'allowsCopy'},
                "allowsLink" => $conf->{'allowsLink'},
                "defaultDestination" => $conf->{'installname'}
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

sub _applistnew {
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
        my $appConfig = _getJSONConfigNew($appConfigPath);
        if ($appConfig) {
            push(@$appList, {
                id => $appConfigPath,
                name => $appConfig->{appname}
            });
        }
    }
    return $appList;
}

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
    my $diff;
    my @operations = _installOperations($app, $appname);
    foreach my $ops (@operations) {
        if ($ops->{action} eq 'move') {
            my $op = $ops->{action};
            my $src = $ops->{from};
            my $tar = $ops->{to};
            #my ($op, $src, $tar) = ($operations[$i], $operations[$i+1], $operations[$i+2]);
            # Compare entries.
            my $msg = '';
            if (! -e $src) { $msg = "Source file ($src) or directory does not exist"; }
            elsif ( -d $src && -f $tar) { $msg =  "Source is a directory, but target is a file. This is most likely bad."; }
            elsif ( -f $src && -d $tar) { $msg =  "Source is a file, but target is a directory. This is most likely bad."; }
            elsif (( -f $src && -f $tar) && (_hashfile($src) ne _hashfile($tar))) {
                                $msg = _getFileDiff($src, $tar);
            }
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
                            elsif ( -f $srcitem && -f $taritem && (_hashfile($srcitem) ne _hashfile($taritem))) {
                                $msg .= _getFileDiff($srcitem, $taritem, $item);
                            }
                            elsif ( -d $srcitem && -d $taritem) { $msg .= "<li>$item is a directory in both source and target. Comparison of subdirectories currently not implemented.</li>"; }
                        }
                    }
                    $msg .= '</ul>';
                }
            } elsif ( -d $src && (! -e $tar)) {
                $msg = "Target directory $tar does not exist. This ist not an error.";
            }
            # Compile result of operation, if messages found
            if ($msg) { $result .= sprintf("<p><strong>%s %s %s</strong></p>%s %s", $op, $src, $tar, $msg, $diff); }
            my $meta = Foswiki::Meta->new($Foswiki::Plugins::SESSION, 'Main', 'WebHome');
            $result = $meta->expandMacros($result);
            $result .= "<b> To see a Diff install Perl Text::Diff and Text::Diff::HTML</b>" unless eval{ require Text::Diff; };
        }
    }
    return {
        "result" => "ok",
        "type" => "html",
        "data" => $result
    };
}

# Get File diff as Twisty...
sub _getFileDiff {
    my ($srcitem, $taritem, $item) = @_;
    my $msg;
    $item .= $item ? ":": "";
    eval { require Text::Diff; };
    if (!$@){
        eval { require Text::Diff::HTML; };
        if (!$@){
            open(my $srcfh, "<:encoding(UTF-8)", $srcitem );
            open(my $tarfh, "<:encoding(UTF-8)", $taritem );
            $msg .= "%TWISTY{link=\"<li>$item Source file and target file have different content</li>\"}%<verbatim>";
            $msg .= Text::Diff::diff($srcfh,$tarfh, { STYLE => 'Text::Diff::HTML'});
            $msg .= "</verbatim>%ENDTWISTY%";
        }
    } else {
        $msg .= "<li>$item Source file and target file have different content</li>";
    }
    return $msg;
}

# Check for existing JSON file. Return undef on error.
sub _getJSONConfigNew {
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

sub _installNew {
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

        print STDERR "Installing FormManagers...\n";
        # Execute 'create form' install actions
        for my $action (@{$subConfig->{installActions}}) {
            my $actionName = $action->{action};
            if($actionName eq 'createForm'){
                my $formName = $action->{formName};
                my $formGroup = $action->{formGroup};
                _actionCreateForm($destinationWeb, $formName, $formGroup);
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

sub _installAllNew {
    my $apps = _applistnew();
    foreach my $app (@$apps){
        my $appDetail = _appdetailnew($app->{id});
        my @installConfigs = @{$appDetail->{appConfig}->{installConfigs}};
        my $result = _installNew($appDetail->{appConfig}->{appname}, $installConfigs[0]);
        if($result->{success} eq JSON::true){
            print STDERR "Success!\n";
        }
        else{
            print STDERR "Installation failed: ".$result->{message}."\n";
        }
    }
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
    if (exists $args->{to} || exists $args->{installname} || exists $conf->{installname}) {
        $installname = $args->{to} || $args->{installname} || $conf->{installname};
    }
    if (exists $args->{mode}) {
        $mode = $args->{mode};
    }

    my $dataDir = $Foswiki::cfg{DataDir};
    my $pubDir = $Foswiki::cfg{PubDir};

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

                my $links = decode_json($args->{links} || "[]");
                my $copies = decode_json($args->{copies} || "[]");

                unless ($src && $tar) {
                    $error = 1;
                    push @log, "Missing parameter 'from' and/or 'to'!";
                }

                push @log, "Move $src to $tar";
                if ($pass eq 'check' && !$args->{linkpartial}) {
                    if (! -e $src) { $error = 1; push @log, "Source file or directory $src does not exist!"; }
                    if (-e $tar)  { $error = 1; push @log, "Target file or directory $tar does already exist!"; }
                } elsif ((($pass eq 'install') and (! $error)) or ($pass eq 'forceinstall')) {
                    my $history = _readHistory($app);
                    if ($args->{copy}) {
                        no warnings 'once';
                        local $File::Copy::Recursive::CopyLink = 0;
                        File::Copy::Recursive::rcopy($src, $tar);
                    } elsif ($args->{move}) {
                        my $dir = $tar;
                        $dir =~ s#/[^/]+/*$##; # remove last dir, because it will be created
                        _makePath($dir);
                        File::Copy::move($src, $tar);
                    } elsif ($args->{link}) {
                        my $dir = $tar;
                        $dir =~ s#/[^/]+/*$##; # remove last dir, because it will be a link
                        _makePath($dir);
                        symlink $src, $tar;
                    } elsif ($args->{linkpartial}) {
                        unless (Foswiki::Func::webExists($installname)) {
                            Foswiki::Func::createWeb($installname);
                        }

                        $tar = $args->{to};
                        my $pubTar;
                        unless ($tar =~ /^$dataDir/) {
                            $pubTar = "$pubDir/$tar";
                            $tar = "$dataDir/$tar";
                        }

                        $src = $args->{from};
                        my $pubSrc;
                        unless ($src =~ /^$dataDir/) {
                            $pubSrc = "$pubDir/$src";
                            $src = "$dataDir/$src";
                        } else {
                            $pubSrc = $src;
                            $pubSrc = s#^\Q$dataDir\E##;
                            $pubSrc = "$pubDir/$pubSrc";
                        }

                        foreach my $topic (@{$links}) {
                            _makePath($tar);
                            symlink "$src/$topic.txt", "$tar/$topic.txt";
                            if($pubTar && $pubSrc && -e "$pubSrc/$topic") {
                                _makePath($pubTar);
                                symlink "$pubSrc/$topic", "$pubTar/$topic";
                            }
                        }

                        {
                            no warnings 'once';
                            local $File::Copy::Recursive::CopyLink = 0;
                            foreach my $topic (@{$copies}) {
                                File::Copy::Recursive::rcopy("$src/$topic.txt", "$tar/$topic.txt");
                                File::Copy::Recursive::rcopy("$pubSrc/$topic", "$pubTar/$topic") if -e "$pubSrc/$topic";
                            }
                        }
                    }

                    unless ($args->{linkpartial}) {
                        $tar =~ s/^$dataDir\///;
                        $tar =~ s/^$pubDir\///;
                        push @{$history->{$args->{link} ? 'linked' : 'installed'}}, $tar;
                    } else {
                        push @{$history->{partials}->{$installname}}, @{$links};
                        push @{$history->{partials}->{$installname}}, @{$copies};
                    }

                    _writeHistory($app, $history);
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
                        $meta->save(dontlog => 1, minor => 1, nohandlers => 1);
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
            "data"   => (sprintf("<p><strong>App action completed successful</strong></p><ul>%s</ul>", $log))
        };
    }
    return $result;
}

# Make sure path exists
# XXX I'm sure there is a perfectly fine lib for this
sub _makePath {
    my ($dst) = @_;
    my $path = '';
    foreach my $part ( split('/', $dst ) ) {
        $path .= "/$part";
        mkdir $path unless -d $path;
    }
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
    my $version = $q->param('version');

    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to use this.'));
    }

    $response->header(-status => !$app ? 400 : 200);
    if($version){
        return encode_json(
            !$app
                ? _texterror('Parameter \'name\' is mandatory')
                : _appdetailnew($app));
    }
    else{
        return encode_json(
            !$app
                ? _texterror('Parameter \'name\' is mandatory')
                : _appdetail($app));
    }
}

sub _RESTtopiclist {
    my ( $session, $subject, $verb, $response ) = @_;

    my $dataDir = $Foswiki::cfg{DataDir};
    my $q = $session->{request};
    my $web = $q->param('webname');

    if ($web !~ /^$dataDir/) {
        $web = "$dataDir/$web";
    }

    if (! -e $web) {
        $response->header(-status => 404);
        return encode_json(_texterror("Given source web does not exist."));
    }

    $web =~ s/$dataDir\///;
    my @topics = Foswiki::Func::getTopicList($web);
    return encode_json({topics => \@topics});
}

# Returns list of managed and unmanaged applications.
sub _RESTapplist {
    my ($session, $subject, $verb, $response) = @_;

    my $q = $session->{request};
    my $apiVersion = $q->param('version');
    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to list installed applications.'));
    }
    if($apiVersion){
        my $isMultisite = _isMultisiteEnabled();
        return encode_json({
            "apps" => _applistnew(),
            "multisite" => {
                "enabled" => _isMultisiteEnabled() ? JSON::true : JSON::false,
                "available" => _isMultisiteAvailable() ? JSON::true : JSON::false
            }
        });
    }
    else{
        return encode_json(_applist());
    }
}

# RestHandler to execute action for app
# installname: optional name to install
sub _RESTappaction {
    my ($session, $subject, $verb, $response) = @_;
    my $q = $session->{request};
    my $name = $q->param('name');
    my $action = $q->param('action');

    my $appId = $q->param('appId');
    my $installConfig = $q->param('installConfig');
    my $version = $q->param('version');


    # This page is only visible for the admin user
    if (!Foswiki::Func::isAnAdmin()) {
        $response->header(-status => 403);
        return encode_json(_texterror('Only Admins are allowed to execute actions.'));
    }
    unless ($name || $appId)   {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'name\' is mandatory'));
    }
    unless ($action || $installConfig) {
        $response->header(-status => 400);
        return encode_json(_texterror('Parameter \'action\' is mandatory'));
    }

    if($version) {
        my $appConfig = _getJSONConfigNew($appId);
        my $appName = $appConfig->{appname};
        my $result = _installNew($appName, decode_json($installConfig));
        return encode_json($result);
    }

    # Check if action available
    if ((_appdetail($name)->{actions}->{$action}) || ($action eq 'install' && $name eq 'all')) {
        if ($action eq 'install') {
            my $opts = {
                from => $q->param('from'),
                to => $q->param('to'),
                copies => $q->param('copylist') || '[]',
                links => $q->param('linklist') || '[]'
            };

            my $type = $q->param('type') || 'move';
            $opts->{$type} = 1;
            return encode_json(_install($name, $opts))
        }
        return encode_json(_appdiff($name)) if $action eq 'diff';

        $response->header(-status => 400);
        return encode_json(_texterror('Action available, but no method defined.'));
    }

    $response->header(-status => 400);
    return encode_json(_texterror('Action not available for app.'));
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
                my $res = _install($name, {move => 1});
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
