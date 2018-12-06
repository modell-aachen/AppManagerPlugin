use Test::Deep;
use Foswiki::Plugins::AppManagerPlugin::AppConfigNormalizer qw( InstallConfig );

describe "the appConfig normalizer" => sub {
    my $expectedConfig = {
            name => 'general',
            webPreferences => [{
                    name => 'WIKILOGOIMG',
                    value => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                }],
        };

    it "is idempotent for array of webpreferences" => sub {
        my $installConfigs = $expectedConfig;

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, $expectedConfig);
    };

    it "transforms webPreferences from object with string as value to array" => sub {
        my $installConfigs = {
                name => 'general',
                webPreferences => {
                    WIKILOGOIMG => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                },
            };
        my $normalizedConfig = InstallConfig->normalize($installConfigs);
        cmp_deeply($normalizedConfig, $expectedConfig);
    };

    it "transforms webPreferences from object with object as values to array" => sub {
        my $installConfigs = {
                name => 'general',
                webPreferences => {
                    WIKILOGOIMG => {
                        value => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                    },
                },
            };

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, {
                    name => 'general',
                    webPreferences => [{
                            name => 'WIKILOGOIMG',
                            value => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                        }],
                });
    };

    it "transforms sitePreferences from object to array" => sub {
        my $installConfigs = {
                name => 'general',
                sitePreferences => {
                    WIKILOGOIMG => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                },
            };

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, {
                    name => 'general',
                    sitePreferences => [{
                            name => 'WIKILOGOIMG',
                            value => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                        }],
                });
    };

    it "transforms preferences in subConfigs" => sub {
        my $installConfigs = {
                name => 'multisite',
                subConfigs => [{
                        name => 'multisite processes',
                        sitePreferences => {
                            WIKILOGOIMG => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                        },
                    }]
            };

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, {
                    name => 'multisite',
                    subConfigs => [{
                            name => 'multisite processes',
                            sitePreferences => [{
                                    name => 'WIKILOGOIMG',
                                    value => '%PUBURLPATH%/System/Multisite/TestPicOu1.png',
                                }],
                        }],
                });
    };

    it "converts an array as value in webpreferences as object to a comma seperated list" => sub {
        my $installConfigs = {
                name => 'general',
                sitePreferences => {
                    language => ['en', 'de'],
                },
            };

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, {
                name => 'general',
                sitePreferences => [{
                        name => 'language',
                        value => 'en,de',
                    }],
            });
    };

    it "converts an array as value in webpreferences as array to a comma seperated list" => sub {
        my $installConfigs = {
                name => 'general',
                sitePreferences => [{
                        name => 'language',
                        value => ['en', 'de'],
                }],
            };

        my $normalizedConfig = InstallConfig->normalize($installConfigs);

        cmp_deeply($normalizedConfig, {
                name => 'general',
                sitePreferences => [{
                        name => 'language',
                        value => 'en,de',
                    }],
            });
    };
};
