use Foswiki::Plugins::AppManagerPlugin::AppManagerException qw( AppManagerException );
use Test::MockModule;
use Test::MockObject;
use Test::Deep;

use Try::Tiny;

sub assertToThrow {
    my ( $exception, $function ) = @_;
    try {
        $function->();
        fail;
    } catch {
        if ((blessed $_) && $_->isa($exception)) {
            pass;
        } else {
            fail($_);
        }
    }
}

sub getAppContribCreator {
    my ( $config ) = @_;
    my $mock = Test::MockObject->new();
    $mock->fake_module( 'Foswiki::Plugins::AppManagerPlugin',
        _getRootDir => sub { return '/var/www/qwikis/qwiki' }
    );
    require Spec::Tester::AppConfigCreator;

    my $creator = Spec::Tester::AppConfigCreator->new($config);
}

describe "the configCreator" => sub {

    it "parses json" => sub {
        my $config = '{"appname": "TestAppContrib", "description": ""}';
        my $creator = getAppContribCreator($config);
        cmp_deeply($creator->{config},
            {appname => "TestAppContrib", description => ""});
    };

    it "throws error if appname does not exist" => sub {
        assertToThrow('Foswiki::Plugins::AppManagerPlugin::AppManagerException', sub {
            my $config = '{"testname": "TestAppContrib", "description": ""}';
            my $creator = getAppContribCreator($config);
        });
    };

    it "throws error if description does not exist" => sub {
        assertToThrow('Foswiki::Plugins::AppManagerPlugin::AppManagerException', sub {
            my $config = '{"appname": "TestAppContrib"}';
            my $creator = getAppContribCreator($config);
        });
    };

    it "throws error if json is not valid" => sub {
        assertToThrow('Foswiki::Plugins::AppManagerPlugin::AppManagerException', sub {
            my $config = '{"testname": "TestAppContrib, "description": ""}';
            my $creator = getAppContribCreator($config);
        });
    };

    it "creates directory for AppConfig" => sub {
        my $config = '{"appname": "TestAppContrib", "description": ""}';
        my $creator = getAppContribCreator($config);

        $creator->run();

        cmp_deeply($creator->{createdDirs},
            ['/var/www/qwikis/qwiki/lib/Foswiki/Contrib/TestAppContrib']);
    };

    it "creates appConfig file" => sub {
        my $config = '{"appname": "TestAppContrib", "description": ""}';
        my $creator = getAppContribCreator($config);
        $creator->run();

        my $file = '/var/www/qwikis/qwiki/lib/Foswiki/Contrib/TestAppContrib/appconfig_new.json';
        ok(exists $creator->{$file});
        is($creator->{$file},
            "{\n   \"appname\" : \"TestAppContrib\",\n"
          . "   \"description\" : \"\"\n}\n");
    };
};
