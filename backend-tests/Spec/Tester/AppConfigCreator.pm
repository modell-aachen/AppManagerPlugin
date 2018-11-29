package Spec::Tester::AppConfigCreator;
use Foswiki::Plugins::AppManagerPlugin::AppConfigCreator;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw( AppConfigCreatorMock );

our @ISA = "Foswiki::Plugins::AppManagerPlugin::AppConfigCreator";

sub AppConfigCreatorMock () { __PACKAGE__ };

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(@_);

    $this->{createdDirs} = [];

    return $this;
}

sub _createDir {
    my ( $this, $directory ) = @_;
    push @{$this->{createdDirs}}, $directory;
}

sub _createAppConfigIn {
    my ( $this, $file ) = @_;
    $this->_writeAppConfigTo(\$this->{$file});
}

